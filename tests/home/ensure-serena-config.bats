#!/usr/bin/env bats
# Exercises home/ides/ensure-serena-config.py (global excluded_tools merge).

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  ENSURE="$REPO_DIR/home/ides/ensure-serena-config.py"
  command -v python3 >/dev/null || skip "python3 not installed"
  python3 -c 'import yaml' 2>/dev/null || skip "PyYAML not installed"
  TMP=$(mktemp -d)
  CONFIG="$TMP/serena_config.yml"
}

teardown() {
  rm -rf "$TMP"
}

@test "creates serena_config.yml with search_for_pattern excluded" {
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -eq 0 ]
  [ -f "$CONFIG" ]
  run python3 -c "
import yaml, sys
d = yaml.safe_load(open(sys.argv[1]))
assert d['excluded_tools'] == ['search_for_pattern'], d
assert d['projects'] == [], d
assert d['trusted_project_path_patterns'] == [], d
" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "merges into existing config and preserves other keys" {
  cat >"$CONFIG" <<'EOF'
language_backend: LSP
excluded_tools:
  - read_file
auth_secret: keep-me
projects:
  - /tmp/some-project
EOF
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -eq 0 ]
  run python3 -c "
import yaml, sys
d = yaml.safe_load(open(sys.argv[1]))
assert d['language_backend'] == 'LSP', d
assert d['auth_secret'] == 'keep-me', d
assert d['projects'] == ['/tmp/some-project'], d
assert d['excluded_tools'] == ['read_file', 'search_for_pattern'], d
assert 'trusted_project_path_patterns' not in d, d
" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "is idempotent when search_for_pattern already excluded" {
  cat >"$CONFIG" <<'EOF'
excluded_tools:
  - search_for_pattern
projects: []
auth_secret: unchanged
EOF
  before=$(cat "$CONFIG")
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -eq 0 ]
  [ "$(cat "$CONFIG")" = "$before" ]
}

@test "seeds projects when missing from an existing file" {
  cat >"$CONFIG" <<'EOF'
excluded_tools:
  - search_for_pattern
EOF
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -eq 0 ]
  run python3 -c "
import yaml, sys
d = yaml.safe_load(open(sys.argv[1]))
assert d['projects'] == [], d
assert d['excluded_tools'] == ['search_for_pattern'], d
assert 'trusted_project_path_patterns' not in d, d
" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "removes search_for_pattern from fixed_tools without excluded_tools" {
  cat >"$CONFIG" <<'EOF'
projects: []
fixed_tools:
  - search_for_pattern
  - read_file
excluded_tools: []
EOF
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -eq 0 ]
  run python3 -c "
import yaml, sys
d = yaml.safe_load(open(sys.argv[1]))
assert d['fixed_tools'] == ['read_file'], d
assert d['excluded_tools'] == [], d
" "$CONFIG"
  [ "$status" -eq 0 ]
  # Second run must stay in fixed mode (no excluded_tools append).
  before=$(cat "$CONFIG")
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -eq 0 ]
  [ "$(cat "$CONFIG")" = "$before" ]
}

@test "rejects sole fixed_tools entry search_for_pattern" {
  cat >"$CONFIG" <<'EOF'
projects: []
fixed_tools:
  - search_for_pattern
EOF
  before=$(cat "$CONFIG")
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -ne 0 ]
  [ "$(cat "$CONFIG")" = "$before" ]
}

@test "rejects duplicate YAML mapping keys without rewriting" {
  # Duplicate `projects` keys — PyYAML would keep only the last value.
  printf '%s\n' \
    'projects:' \
    '  - /tmp/first' \
    'projects:' \
    '  - /tmp/second' \
    'excluded_tools: []' >"$CONFIG"
  before=$(cat "$CONFIG")
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -ne 0 ]
  [ "$(cat "$CONFIG")" = "$before" ]
}

@test "accepts YAML merge keys when updating" {
  cat >"$CONFIG" <<'EOF'
defaults: &defaults
  language_backend: LSP
  projects: []

<<: *defaults
excluded_tools:
  - read_file
EOF
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -eq 0 ]
  run python3 -c "
import yaml, sys
d = yaml.safe_load(open(sys.argv[1]))
assert d['language_backend'] == 'LSP', d
assert d['projects'] == [], d
assert d['excluded_tools'] == ['read_file', 'search_for_pattern'], d
" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "atomic write preserves existing file mode" {
  cat >"$CONFIG" <<'EOF'
projects: []
excluded_tools: []
EOF
  chmod 600 "$CONFIG"
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -eq 0 ]
  # Portable mode check (no GNU stat required).
  run python3 -c "
import os, stat, sys
mode = stat.S_IMODE(os.stat(sys.argv[1]).st_mode)
assert mode == 0o600, oct(mode)
" "$CONFIG"
  [ "$status" -eq 0 ]
}
@test "appends when excluded_tools is empty list" {
  cat >"$CONFIG" <<'EOF'
excluded_tools: []
projects: []
web_dashboard: true
EOF
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -eq 0 ]
  run python3 -c "
import yaml, sys
d = yaml.safe_load(open(sys.argv[1]))
assert d['excluded_tools'] == ['search_for_pattern'], d
assert d['web_dashboard'] is True, d
" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "rejects non-list excluded_tools" {
  cat >"$CONFIG" <<'EOF'
excluded_tools: search_for_pattern
EOF
  run python3 "$ENSURE" "$CONFIG"
  [ "$status" -ne 0 ]
}
