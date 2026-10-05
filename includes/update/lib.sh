#!/usr/bin/env bash
# Publisher-only helpers on top of modules/update/pin-lib.sh.
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/modules/update/pin-lib.sh"

read_nix_string_assign() {
  local file=$1 name=$2
  python3 - "$file" "$name" <<'PY'
import pathlib, re, sys

text = pathlib.Path(sys.argv[1]).read_text()
name = sys.argv[2]
match = re.search(rf'^\s*{re.escape(name)}\s*=\s*"([^"]*)"\s*;', text, re.M)
if not match:
    raise SystemExit(f"read_nix_string_assign: {name} not found in {sys.argv[1]}")
print(match.group(1))
PY
}

replace_nix_string_assign() {
  local file=$1 name=$2 value=$3
  if update_dry_run; then
    echo "dry-run: $file: $name = \"$value\""
    return 0
  fi
  python3 - "$file" "$name" "$value" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
name = sys.argv[2]
value = sys.argv[3]
text = path.read_text()
pat = re.compile(rf'^(\s*{re.escape(name)}\s*=\s*")[^"]*("\s*;)', re.M)
new, count = pat.subn(rf"\g<1>{value}\2", text, count=1)
if count != 1:
    raise SystemExit(
        f"replace_nix_string_assign: expected 1 match for {name} in {path}, got {count}"
    )
path.write_text(new)
PY
}

replace_attr_sha256() {
  local file=$1 attr=$2 value=$3
  if update_dry_run; then
    echo "dry-run: $file: $attr.sha256 = \"$value\""
    return 0
  fi
  python3 - "$file" "$attr" "$value" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
attr = sys.argv[2]
value = sys.argv[3]
text = path.read_text()
pat = re.compile(
    rf"({re.escape(attr)}\s*=\s*\{{(?:[^{{}}]|\n)*?sha256\s*=\s*\")[^\"]*(\")",
    re.M,
)
new, count = pat.subn(rf"\g<1>{value}\2", text, count=1)
if count != 1:
    raise SystemExit(
        f"replace_attr_sha256: expected 1 match for {attr} in {path}, got {count}"
    )
path.write_text(new)
PY
}
