#!/usr/bin/env python3
"""Ensure Serena global config excludes search_for_pattern.

Merges into ~/.serena/serena_config.yml (or a path passed as argv[1]).
On create: seeds projects: [] and trusted_project_path_patterns: [] (Serena
defaults a missing trust key to ["**"]). Rejects duplicate YAML mapping keys.
When fixed_tools is in use, removes search_for_pattern from that list only
(never empties it; never pairs nonempty fixed_tools with excluded_tools).
Idempotent.
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


class DuplicateKeyError(ValueError):
    """Raised when a YAML mapping repeats a key."""


def _no_duplicates_loader() -> type[yaml.SafeLoader]:
    class Loader(yaml.SafeLoader):
        pass

    def construct_mapping(loader: yaml.SafeLoader, node: yaml.nodes.MappingNode, deep: bool = False):
        mapping: dict = {}
        for key_node, value_node in node.value:
            key = loader.construct_object(key_node, deep=deep)
            if key in mapping:
                raise DuplicateKeyError(f"duplicate YAML key: {key!r}")
            mapping[key] = loader.construct_object(value_node, deep=deep)
        return mapping

    Loader.add_constructor(
        yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
        construct_mapping,
    )
    return Loader


def _load_mapping(text: str) -> dict:
    try:
        data = yaml.load(text, Loader=_no_duplicates_loader()) or {}
    except DuplicateKeyError as e:
        print(f"ensure-serena-config: {e}", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"ensure-serena-config: invalid YAML: {e}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(data, dict):
        print("ensure-serena-config: expected a YAML mapping", file=sys.stderr)
        sys.exit(1)
    return data


def ensure(path: Path) -> bool:
    """Return True if the file was created or updated."""
    path.parent.mkdir(parents=True, exist_ok=True)
    created = not (path.is_file() and path.stat().st_size > 0)
    if not created:
        data = _load_mapping(path.read_text(encoding="utf-8"))
    else:
        data = {}

    changed = created

    # Serena 1.7+ requires projects once the config file exists.
    if "projects" not in data:
        data["projects"] = []
        changed = True

    # Missing trusted_project_path_patterns defaults to ["**"] in Serena 1.7.
    # Seed a restrictive empty list only for brand-new configs.
    if created:
        data["trusted_project_path_patterns"] = []
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
    # Nonempty fixed_tools is fixed mode: Serena rejects pairing it with
    # excluded_tools. Drop TOOL from the allowlist only.
    if isinstance(fixed, list) and fixed:
        if TOOL in fixed:
            remaining = [t for t in fixed if t != TOOL]
            if not remaining:
                print(
                    "ensure-serena-config: refusing to remove "
                    f"{TOOL!r} from fixed_tools when it is the only entry "
                    "(empty fixed_tools enables Serena's default tool set)",
                    file=sys.stderr,
                )
                sys.exit(1)
            data["fixed_tools"] = remaining
            changed = True
    elif TOOL not in tools:
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
