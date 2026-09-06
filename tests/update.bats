#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# ^ SC2030/SC2031: each @test looks like a subshell, so PATH/DEVENV_ROOT
# exports are reported as leaking or getting lost; they are deliberately per-test.
# update dispatcher and pin helpers. No live registry access.

bats_require_minimum_version 1.5.0

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  UPDATE_SH="$REPO_DIR/modules/update.sh"
  FIXTURE=$(mktemp -d)
  BIN=$(mktemp -d)
  ORIG_PATH=$PATH
  export DEVENV_ROOT="$FIXTURE"
  export STUB_LOG="$FIXTURE/devenv.log"
}

teardown() {
  PATH=$ORIG_PATH
  rm -rf "$FIXTURE" "$BIN"
}

write_devenv_stub() {
  local exit_code=${1:-0}
  cat >"$BIN/devenv" <<EOF
#!/usr/bin/env bash
printf 'devenv-stub:%s\n' "\$*" >>"\$STUB_LOG"
exit ${exit_code}
EOF
  chmod +x "$BIN/devenv"
}

@test "consumer mode runs devenv update, leaves pins, prints copier hint" {
  mkdir -p "$FIXTURE/home"
  printf '  braveSearchMcpVersion = "0.0.0";\n' >"$FIXTURE/home/llm-context.nix"
  write_devenv_stub 0

  PATH="$BIN:$PATH" run bash "$UPDATE_SH"
  [ "$status" -eq 0 ]
  grep -qx 'devenv-stub:update' "$STUB_LOG"
  [[ $output == *"copier update"* ]]
  [[ $output == *"home/llm-context.nix"* ]]
  grep -q 'braveSearchMcpVersion = "0.0.0"' "$FIXTURE/home/llm-context.nix"
}

@test "consumer mode runs executable update.local.sh" {
  write_devenv_stub 0
  cat >"$FIXTURE/update.local.sh" <<'EOF'
#!/usr/bin/env bash
printf 'local-hook\n' >"$DEVENV_ROOT/local.marker"
EOF
  chmod +x "$FIXTURE/update.local.sh"

  PATH="$BIN:$PATH" run bash "$UPDATE_SH"
  [ "$status" -eq 0 ]
  [ -f "$FIXTURE/local.marker" ]
}

@test "template mode runs a mocked refresher and does not call devenv update" {
  mkdir -p "$FIXTURE/includes/update"
  printf '# helpers\n' >"$FIXTURE/includes/update/lib.sh"
  cat >"$FIXTURE/includes/update/dummy.sh" <<'EOF'
#!/usr/bin/env bash
echo "dummy-refresher"
printf 'refreshed\n' >"$DEVENV_ROOT/refreshed.marker"
EOF
  write_devenv_stub 99

  PATH="$BIN:$PATH" run bash "$UPDATE_SH"
  [ "$status" -eq 0 ]
  [[ $output == *dummy-refresher* ]]
  [[ $output == *template\ mode* ]]
  [ -f "$FIXTURE/refreshed.marker" ]
  [ ! -e "$STUB_LOG" ]
}

@test "replace_nix_string_assign edits one assignment; dry-run does not write" {
  command -v python3 >/dev/null || skip "python3 not installed"
  # shellcheck disable=SC1091
  source "$REPO_DIR/includes/update/lib.sh"
  printf '  fooVersion = "old";\n' >"$FIXTURE/pin.nix"

  UPDATE_DRY_RUN=1 replace_nix_string_assign "$FIXTURE/pin.nix" fooVersion new
  grep -q 'fooVersion = "old"' "$FIXTURE/pin.nix"

  unset UPDATE_DRY_RUN
  replace_nix_string_assign "$FIXTURE/pin.nix" fooVersion new
  grep -q 'fooVersion = "new"' "$FIXTURE/pin.nix"
}

@test "lib.sh npm_latest encodes a scoped package and uses mocked curl" {
  command -v jq >/dev/null || skip "jq not installed"
  cat >"$BIN/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$STUB_LOG"
for arg in "$@"; do
  if [[ $arg == *"%2f"* ]]; then
    printf '%s\n' '{"version":"8.8.8"}'
    exit 0
  fi
done
exit 1
EOF
  chmod +x "$BIN/curl"

  export PATH="$BIN:$PATH"
  # shellcheck disable=SC1091
  source "$REPO_DIR/includes/update/lib.sh"
  run npm_latest @brave/brave-search-mcp-server
  [ "$status" -eq 0 ]
  [ "$output" = "8.8.8" ]
  grep -q '%2f' "$STUB_LOG"
}

@test "npm-mcp refresher rewrites pins without hitting the live registry" {
  command -v jq >/dev/null || skip "jq not installed"
  command -v python3 >/dev/null || skip "python3 not installed"
  mkdir -p "$FIXTURE/home"
  cp "$REPO_DIR/home/llm-context.nix" "$FIXTURE/home/llm-context.nix"

  cat >"$BIN/curl" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  if [[ $arg == *brave-search-mcp-server* ]]; then
    printf '%s\n' '{"version":"8.8.8"}'
    exit 0
  fi
  if [[ $arg == *firecrawl-mcp* ]]; then
    printf '%s\n' '{"version":"9.9.9"}'
    exit 0
  fi
done
exit 1
EOF
  chmod +x "$BIN/curl"

  UPDATE_ROOT=$FIXTURE PATH="$BIN:$PATH" run bash "$REPO_DIR/includes/update/npm-mcp.sh"
  [ "$status" -eq 0 ]
  grep -q 'braveSearchMcpVersion = "8.8.8"' "$FIXTURE/home/llm-context.nix"
  grep -q 'firecrawlMcpVersion = "9.9.9"' "$FIXTURE/home/llm-context.nix"
  grep -q '@brave/brave-search-mcp-server' "$FIXTURE/home/llm-context.nix"
}

@test "npm-mcp refresher honors UPDATE_DRY_RUN" {
  command -v jq >/dev/null || skip "jq not installed"
  command -v python3 >/dev/null || skip "python3 not installed"
  mkdir -p "$FIXTURE/home"
  cp "$REPO_DIR/home/llm-context.nix" "$FIXTURE/home/llm-context.nix"
  before=$(sha256sum "$FIXTURE/home/llm-context.nix" | awk '{print $1}')

  cat >"$BIN/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"version":"8.8.8"}'
EOF
  chmod +x "$BIN/curl"

  UPDATE_ROOT=$FIXTURE UPDATE_DRY_RUN=1 PATH="$BIN:$PATH" run bash "$REPO_DIR/includes/update/npm-mcp.sh"
  [ "$status" -eq 0 ]
  [[ $output == *dry-run* ]]
  after=$(sha256sum "$FIXTURE/home/llm-context.nix" | awk '{print $1}')
  [ "$before" = "$after" ]
}
