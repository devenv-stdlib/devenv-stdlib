#!/usr/bin/env bash
# Rewrite stdlib/version.nix `version` for semantic-release.
# apiVersion is derived from the major component; do not edit it here.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: stdlib-version.sh <version>" >&2
  exit 1
fi

version=$1
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
file=$root/stdlib/version.nix

python3 - "$file" "$version" <<'PY'
import pathlib, re, sys

path, version = sys.argv[1:]
file = pathlib.Path(path)
text = file.read_text()
new, count = re.subn(
    r'^( *)version = "[^"]*"',
    lambda match: f'{match.group(1)}version = "{version}"',
    text,
    count=1,
    flags=re.M,
)
if count != 1:
    raise SystemExit(f"stdlib-version: expected 1 version assignment in {path}, got {count}")
file.write_text(new)
PY
