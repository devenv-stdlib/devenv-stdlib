#!/usr/bin/env python3
"""Ensure Serena global config excludes search_for_pattern.

Merges into ~/.serena/serena_config.yml (or a path passed as argv[1]).
Seeds projects: [] when missing; removes search_for_pattern from fixed_tools
when excluding it. Idempotent.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError as e:  # pragma: no cover
    print(f"ensure-serena-config: PyYAML required: {e}", file=sys.stderr)
    sys.exit(1)

TOOL = "search_for_pattern"


def ensure(path: Path) -> bool:
    """Return True if the file was created or updated."""
    path.parent.mkdir(parents=True, exist_ok=True)
    created = not (path.is_file() and path.stat().st_size > 0)
    if not created:
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        if not isinstance(data, dict):
            print(
                f"ensure-serena-config: expected a YAML mapping in {path}",
                file=sys.stderr,
            )
            sys.exit(1)
    else:
        data = {}

    changed = created

    # Serena 1.7+ requires projects once the config file exists.
    if "projects" not in data:
        data["projects"] = []
        changed = True

    tools = data.get("excluded_tools")
    if tools is None:
        tools = []
    if not isinstance(tools, list):
        print(
            f"ensure-serena-config: excluded_tools must be a list in {path}",
            file=sys.stderr,
        )
        sys.exit(1)

    fixed = data.get("fixed_tools")
    if isinstance(fixed, list) and TOOL in fixed:
        data["fixed_tools"] = [t for t in fixed if t != TOOL]
        changed = True

    if TOOL not in tools:
        data["excluded_tools"] = list(tools) + [TOOL]
        changed = True
    else:
        data["excluded_tools"] = list(tools)

    if not changed:
        return False

    path.write_text(
        yaml.safe_dump(
            data,
            default_flow_style=False,
            sort_keys=False,
            allow_unicode=True,
        ),
        encoding="utf-8",
    )
    return True


def main() -> None:
    path = (
        Path(sys.argv[1])
        if len(sys.argv) > 1
        else Path.home() / ".serena" / "serena_config.yml"
    )
    ensure(path)


if __name__ == "__main__":
    main()
