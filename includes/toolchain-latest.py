#!/usr/bin/env python3
"""Toolchain catalog for Copier max defaults and devenv version policy.

Fetches endoflife.date cycles, records latest patch and EOL, and writes:
  modules/toolchain-catalog.json  (Nix: latest patch per non-EOL cycle)
  includes/toolchain-latest.yml   (Copier max defaults, aligned to min)

Usage:
  python3 includes/toolchain-latest.py refresh
  python3 includes/toolchain-latest.py self-test
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from datetime import date
from io import BytesIO
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DEFAULT_YAML = HERE / "toolchain-latest.yml"
DEFAULT_JSON = ROOT / "modules" / "toolchain-catalog.json"
API = "https://endoflife.date/api/{product}.json"
USER_AGENT = "devenv4monorepo/toolchain-latest"

# product on endoflife.date → default supported.*.min in copier.yml
PRODUCTS = {
    "rust": ("rust", "1.85.0"),
    "go": ("go", "1.22.0"),
    "python": ("python", "3.12"),
    "nodejs": ("nodejs", "22"),
    "bun": ("bun", "1.1.0"),
    "deno": ("deno", "2.0.0"),
}


def parse_version(value: str) -> list[int]:
    return [int(part) for part in value.split(".")]


def format_version(parts: list[int]) -> str:
    return ".".join(str(part) for part in parts)


def align_max(min_v: str, latest_v: str) -> str:
    """Shape latest so enumerateRange(min, max) steps one component."""
    minimum = parse_version(min_v)
    latest = parse_version(latest_v)
    if len(latest) < len(minimum):
        latest = latest + [0] * (len(minimum) - len(latest))
    else:
        latest = latest[: len(minimum)]
    if latest < minimum:
        return min_v
    diffs = [i for i, (a, b) in enumerate(zip(minimum, latest)) if a != b]
    if len(diffs) <= 1:
        return format_version(latest)
    first = diffs[0]
    return format_version(latest[: first + 1] + minimum[first + 1 :])


def is_eol(eol, today: str) -> bool:
    if eol is True:
        return True
    if eol is False or eol is None:
        return False
    return str(eol)[:10] <= today


def parse_releases(rows: list[dict], today: str) -> list[dict]:
    releases = []
    for row in rows:
        cycle = str(row["cycle"])
        latest = str(row.get("latest") or cycle)
        releases.append(
            {
                "cycle": cycle,
                "latest": latest,
                "eol": is_eol(row.get("eol"), today),
            }
        )
    return releases


def newest_supported(releases: list[dict]) -> str:
    for row in releases:
        if not row["eol"]:
            return row["latest"]
    if not releases:
        raise ValueError("empty release list")
    return releases[0]["latest"]


def fetch_rows(product: str, *, opener=None) -> list:
    url = API.format(product=product)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    openurl = opener or urllib.request.urlopen
    with openurl(req) as resp:
        payload = json.load(resp)
    if not isinstance(payload, list):
        raise ValueError(f"{product}: expected a JSON list")
    return payload


def collect(*, opener=None, today: str | None = None) -> tuple[dict, dict[str, str]]:
    today = today or date.today().isoformat()
    catalog = {}
    latest = {}
    for name, (product, min_v) in PRODUCTS.items():
        releases = parse_releases(fetch_rows(product, opener=opener), today)
        newest = newest_supported(releases)
        catalog[name] = {"latest": newest, "releases": releases}
        latest[name] = align_max(min_v, newest)
    return catalog, latest


def render_yaml(versions: dict[str, str]) -> str:
    lines = [
        "# Latest non-EOL stables from https://endoflife.date, aligned to the",
        "# default supported.*.min component counts. Refresh with:",
        "# refresh-toolchain-latest",
    ]
    for name in PRODUCTS:
        lines.append(f'{name}: "{versions[name]}"')
    return "\n".join(lines) + "\n"


def refresh(
    yaml_path: Path = DEFAULT_YAML,
    json_path: Path = DEFAULT_JSON,
    *,
    opener=None,
    today: str | None = None,
) -> tuple[dict, dict[str, str]]:
    catalog, latest = collect(opener=opener, today=today)
    yaml_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.parent.mkdir(parents=True, exist_ok=True)
    yaml_path.write_text(render_yaml(latest), encoding="utf-8")
    json_path.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")
    return catalog, latest


def _self_test() -> None:
    assert align_max("1.80.0", "1.98.1") == "1.98.0"
    assert align_max("1.22.0", "1.27.1") == "1.27.0"
    assert align_max("3.12", "3.14.7") == "3.14"
    assert align_max("22", "26.8.1") == "26"
    assert align_max("1.1.0", "1.4.2") == "1.4.0"
    assert align_max("2.0.0", "2.9.6") == "2.9.0"
    assert align_max("1.85.0", "1.80.0") == "1.85.0"
    assert is_eol(False, "2026-09-05") is False
    assert is_eol(True, "2026-09-05") is True
    assert is_eol("2026-08-19", "2026-09-05") is True
    assert is_eol("2028-10-31", "2026-09-05") is False
    rows = [
        {"cycle": "3.14", "latest": "3.14.7", "eol": "2030-10-31"},
        {"cycle": "3.9", "latest": "3.9.25", "eol": "2025-10-31"},
    ]
    releases = parse_releases(rows, "2026-09-05")
    assert releases[0] == {"cycle": "3.14", "latest": "3.14.7", "eol": False}
    assert releases[1] == {"cycle": "3.9", "latest": "3.9.25", "eol": True}
    assert newest_supported(releases) == "3.14.7"

    class _JsonResp:
        def __init__(self, body):
            self._raw = BytesIO(json.dumps(body).encode())

        def __enter__(self):
            return self._raw

        def __exit__(self, *args):
            return False

    def opener(req):
        if req.full_url.endswith("/python.json"):
            return _JsonResp(rows)
        if req.full_url.endswith("/rust.json"):
            return _JsonResp([{"cycle": "1.98", "latest": "1.98.1", "eol": False}])
        if req.full_url.endswith("/go.json"):
            return _JsonResp([{"cycle": "1.27", "latest": "1.27.1", "eol": False}])
        if req.full_url.endswith("/nodejs.json"):
            return _JsonResp([{"cycle": "26", "latest": "26.8.1", "eol": False}])
        if req.full_url.endswith("/bun.json"):
            return _JsonResp([{"cycle": "1", "latest": "1.4.2", "eol": False}])
        if req.full_url.endswith("/deno.json"):
            return _JsonResp([{"cycle": "2.9", "latest": "2.9.6", "eol": False}])
        raise AssertionError(req.full_url)

    catalog, latest = collect(opener=opener, today="2026-09-05")
    assert catalog["python"]["latest"] == "3.14.7"
    assert latest["python"] == "3.14"
    assert latest["rust"] == "1.98.0"
    print("toolchain-latest self-test ok")


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    cmd, *rest = argv
    if cmd == "self-test":
        _self_test()
        return 0
    if cmd == "refresh":
        if rest:
            print("usage: refresh", file=sys.stderr)
            return 2
        catalog, latest = refresh()
        print(f"wrote {DEFAULT_YAML}")
        print(f"wrote {DEFAULT_JSON}")
        for name, value in latest.items():
            supported = sum(1 for r in catalog[name]["releases"] if not r["eol"])
            print(f"  {name}: {value} ({supported} non-EOL cycles)")
        return 0
    print(f"unknown command: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (urllib.error.URLError, OSError, ValueError, json.JSONDecodeError) as err:
        print(f"toolchain-latest: {err}", file=sys.stderr)
        sys.exit(1)
