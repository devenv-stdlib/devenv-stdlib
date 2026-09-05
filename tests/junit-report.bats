#!/usr/bin/env bats
# Parser/writer checks for tests/junit-report.py. Does not run nix-unit or qemu.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  REPORT="$REPO_DIR/tests/junit-report.py"
  command -v python3 >/dev/null || skip "python3 not installed"
}

@test "nix-unit junit maps failures to source files" {
  fixture="$BATS_TEST_TMPDIR/nix-unit.txt"
  out="$BATS_TEST_TMPDIR/nix-unit.xml"
  cat >"$fixture" <<'EOF'
✅ testResolvedVersionsNullMin
❌ testResolvedVersionsMinOnly
{ expected = [ "3.12" ]; } != { expr = [ ]; }

☢️ testResolvedVersionsMinEqualsMax
error: NO U

😢 1/3 successful
error: Tests failed
EOF
  run python3 "$REPORT" nix-unit --from-text "$fixture" --output "$out" --unit-dir "$REPO_DIR/tests/unit" --root "$REPO_DIR"
  [ "$status" -eq 1 ]
  grep -q 'name="testResolvedVersionsNullMin"' "$out"
  grep -q 'file="tests/unit/versions.nix"' "$out"
  grep -q 'name="testResolvedVersionsMinOnly"' "$out"
  grep -q '<failure' "$out"
  grep -q '<error' "$out"
  grep -q 'line="' "$out"
}

@test "nixos-test junit can record a skipped run" {
  out="$BATS_TEST_TMPDIR/nixos-skip.xml"
  run python3 "$REPORT" nixos-test --skipped --status 0 --output "$out" --root "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q '<skipped' "$out"
  grep -q 'file="tests/integration/default.nix"' "$out"
}

@test "nixos-test junit points at the integration file" {
  log="$BATS_TEST_TMPDIR/nixos.log"
  out="$BATS_TEST_TMPDIR/nixos-test.xml"
  printf 'machine: boom\n' >"$log"
  run python3 "$REPORT" nixos-test --status 1 --log "$log" --output "$out" --root "$REPO_DIR"
  [ "$status" -eq 1 ]
  grep -q 'file="tests/integration/default.nix"' "$out"
  grep -q 'name="devenv"' "$out"
  grep -q '<failure' "$out"
  grep -q 'boom' "$out"
}

@test "enrich-bats adds file and line from the suite" {
  src="$BATS_TEST_TMPDIR/bats.xml"
  out="$BATS_TEST_TMPDIR/bats-out.xml"
  cat >"$src" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="junit-report.bats" tests="2" failures="1">
    <testcase classname="junit-report.bats" name="nix-unit junit maps failures to source files">
      <failure message="failed">nope</failure>
    </testcase>
    <testcase classname="setup/setup.bats" name="setup.sh passes shellcheck" />
  </testsuite>
</testsuites>
EOF
  run python3 "$REPORT" enrich-bats --input "$src" --output "$out" --root "$REPO_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" != *Traceback* ]]
  grep -q 'file="tests/junit-report.bats"' "$out"
  grep -q 'line="10"' "$out"
  grep -q 'file="tests/setup/setup.bats"' "$out"
}
