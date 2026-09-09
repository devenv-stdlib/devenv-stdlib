#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# ^ SC2030/SC2031: each @test looks like a subshell, so PATH/DEVENV_ROOT
# exports are reported as leaking or getting lost; they are deliberately per-test.
# update dispatcher and pin helpers. No live registry access.

bats_require_minimum_version 1.5.0

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  UPDATE_SH="$REPO_DIR/modules/update/update.sh"
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

@test "consumer mode runs devenv update, local-catalog, leaves pins, prints copier hint" {
  mkdir -p "$FIXTURE/modules/non-nix" "$FIXTURE/modules/update"
  cat >"$FIXTURE/modules/non-nix/catalog.toml" <<'EOF'
# Shipped. Docs: https://example.test
[[tool]]
name = "shipped"
kind = "cli"
scope = "user"
pin = "0.0.0"
mise = "npm:shipped"
EOF
  # stub local-catalog so consumer mode does not need network/nix
  cat >"$FIXTURE/modules/update/local-catalog.sh" <<'EOF'
#!/usr/bin/env bash
printf 'local-catalog-stub\n'
EOF
  write_devenv_stub 0

  PATH="$BIN:$PATH" run bash "$UPDATE_SH"
  [ "$status" -eq 0 ]
  grep -qx 'devenv-stub:update' "$STUB_LOG"
  [[ $output == *"copier update"* || $output == *"catalog.local.toml"* ]]
  [[ $output == *local-catalog-stub* ]]
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

@test "local-catalog dry-run bumps pins and preserves comments" {
  command -v python3 >/dev/null || skip "python3 not installed"
  command -v jq >/dev/null || skip "jq not installed"
  mkdir -p "$FIXTURE/modules/non-nix" "$FIXTURE/modules/update"
  cp "$REPO_DIR/modules/update/pin-lib.sh" "$FIXTURE/modules/update/pin-lib.sh"
  cp "$REPO_DIR/modules/update/local-catalog.sh" "$FIXTURE/modules/update/local-catalog.sh"
  # empty shipped catalog so resolve only sees local (via still needs nixpkgs)
  printf '# shipped empty\n' >"$FIXTURE/modules/non-nix/catalog.toml"
  cat >"$FIXTURE/modules/non-nix/catalog.local.toml" <<'EOF'
# Team CLI. Docs: https://example.test/team-cli
[[tool]]
name = "team-cli"
kind = "cli"
scope = "project"
pin = "0.0.0"
mise = "npm:team-cli"
EOF
  cat >"$BIN/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"version":"2.2.2"}'
EOF
  chmod +x "$BIN/curl"
  cat >"$BIN/mise" <<'EOF'
#!/usr/bin/env bash
printf 'mise:%s\n' "$*" >>"$STUB_LOG"
EOF
  chmod +x "$BIN/mise"
  cat >"$BIN/nix" <<'EOF'
#!/usr/bin/env bash
# pretend not promotable
printf 'cli\n'
EOF
  chmod +x "$BIN/nix"

  UPDATE_ROOT=$FIXTURE UPDATE_DRY_RUN=1 PATH="$BIN:$PATH" run bash "$FIXTURE/modules/update/local-catalog.sh"
  [ "$status" -eq 0 ]
  [[ $output == *dry-run* ]]
  grep -q 'Docs: https://example.test/team-cli' "$FIXTURE/modules/non-nix/catalog.local.toml"
  grep -q 'pin = "0.0.0"' "$FIXTURE/modules/non-nix/catalog.local.toml"
}

@test "non-nix refresher rewrites catalog pins without hitting the live registry" {
  command -v python3 >/dev/null || skip "python3 not installed"
  mkdir -p "$FIXTURE/modules/non-nix" "$FIXTURE/home"
  cat >"$FIXTURE/modules/non-nix/catalog.toml" <<'EOF'
# Brave Search MCP. Docs: https://example.test/brave
[[tool]]
name = "brave-search-mcp"
kind = "cli"
scope = "user"
pin = "0.0.0"
mise = "npm:@brave/brave-search-mcp-server"

# Firecrawl MCP. Docs: https://example.test/firecrawl
[[tool]]
name = "firecrawl-mcp"
kind = "cli"
scope = "user"
pin = "0.0.0"
mise = "npm:firecrawl-mcp"
EOF
  printf 'sha256 = "old";\n' >"$FIXTURE/home/vscode-ext-lib.nix"

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

  UPDATE_ROOT=$FIXTURE PATH="$BIN:$PATH" run bash "$REPO_DIR/includes/update/non-nix.sh"
  [ "$status" -eq 0 ]
  grep -q 'pin = "8.8.8"' "$FIXTURE/modules/non-nix/catalog.toml"
  grep -q 'pin = "9.9.9"' "$FIXTURE/modules/non-nix/catalog.toml"
  grep -q 'Docs: https://example.test/brave' "$FIXTURE/modules/non-nix/catalog.toml"
  grep -q 'Docs: https://example.test/firecrawl' "$FIXTURE/modules/non-nix/catalog.toml"
}

@test "skills refresher runs the CLI update in the repo root" {
  printf '{"version":1,"skills":{}}\n' >"$FIXTURE/skills-lock.json"
  cat >"$BIN/skills" <<'EOF'
#!/usr/bin/env bash
printf '%s\n%s\n' "$PWD" "$*" >"$STUB_LOG"
EOF
  chmod +x "$BIN/skills"

  UPDATE_ROOT=$FIXTURE PATH="$BIN:$PATH" run bash "$REPO_DIR/includes/update/skills.sh"
  [ "$status" -eq 0 ]
  run cat "$STUB_LOG"
  [ "${lines[0]}" = "$FIXTURE" ]
  [ "${lines[1]}" = "update -y -p" ]
}

@test "skills refresher needs skills-lock.json and honors UPDATE_DRY_RUN" {
  cat >"$BIN/skills" <<'EOF'
#!/usr/bin/env bash
printf 'ran\n' >"$STUB_LOG"
EOF
  chmod +x "$BIN/skills"

  UPDATE_ROOT=$FIXTURE PATH="$BIN:$PATH" run bash "$REPO_DIR/includes/update/skills.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"no skills-lock.json"* ]]

  printf '{"version":1,"skills":{}}\n' >"$FIXTURE/skills-lock.json"
  UPDATE_ROOT=$FIXTURE UPDATE_DRY_RUN=1 PATH="$BIN:$PATH" run bash "$REPO_DIR/includes/update/skills.sh"
  [ "$status" -eq 0 ]
  [[ $output == *dry-run* ]]
  [ ! -e "$STUB_LOG" ]
}

@test "non-nix refresher honors UPDATE_DRY_RUN" {
  command -v python3 >/dev/null || skip "python3 not installed"
  mkdir -p "$FIXTURE/modules/non-nix"
  cat >"$FIXTURE/modules/non-nix/catalog.toml" <<'EOF'
# Brave Search MCP. Docs: https://example.test/brave
[[tool]]
name = "brave-search-mcp"
kind = "cli"
scope = "user"
pin = "0.0.0"
mise = "npm:@brave/brave-search-mcp-server"
EOF
  before=$(sha256sum "$FIXTURE/modules/non-nix/catalog.toml" | awk '{print $1}')

  cat >"$BIN/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"version":"8.8.8"}'
EOF
  chmod +x "$BIN/curl"

  UPDATE_ROOT=$FIXTURE UPDATE_DRY_RUN=1 PATH="$BIN:$PATH" run bash "$REPO_DIR/includes/update/non-nix.sh"
  [ "$status" -eq 0 ]
  [[ $output == *dry-run* ]]
  after=$(sha256sum "$FIXTURE/modules/non-nix/catalog.toml" | awk '{print $1}')
  [ "$before" = "$after" ]
}
