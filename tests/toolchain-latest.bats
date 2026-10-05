#!/usr/bin/env bats
# Unit tests for includes/toolchain-latest.py. Network is not used.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_DIR/includes/toolchain-latest.py"
  command -v python3 >/dev/null || skip "python3 not installed"
}

@test "toolchain-latest self-test" {
  run python3 "$SCRIPT" self-test
  [ "$status" -eq 0 ]
  [[ $output == *"self-test ok"* ]]
}

@test "toolchain-latest catalog has every toolchain-latest max default" {
  for name in rust go python nodejs bun deno; do
    grep -q "^${name}: \"" "$REPO_DIR/includes/toolchain-latest.yml"
  done
}

@test "toolchain catalog json lists releases with latest and eol" {
  [ -f "$REPO_DIR/modules/languages/catalog.json" ]
  python3 -c '
import json, sys
p = json.load(open(sys.argv[1]))
for name in ("rust", "go", "python", "nodejs", "bun", "deno"):
    assert name in p, name
    assert p[name]["releases"], name
    row = p[name]["releases"][0]
    assert "cycle" in row and "latest" in row and "eol" in row, name
' "$REPO_DIR/modules/languages/catalog.json"
}
