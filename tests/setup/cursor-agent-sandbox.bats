#!/usr/bin/env bats
# Validates Cursor Agent sandbox AppArmor profile packaging (no root required).

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PROFILE="$REPO_DIR/includes/cursor-agent-sandbox/apparmor.d/cursor-sandbox-nix"
  INSTALL="$REPO_DIR/includes/cursor-agent-sandbox/install.sh"
}

@test "AppArmor profile source exists and names Nix and agent-cli helpers" {
  [ -f "$PROFILE" ]
  grep -q 'abi <abi/5.0>' "$PROFILE"
  grep -q 'profile cursor_sandbox_nix' "$PROFILE"
  grep -q '/nix/store/\*-cursor-\*/lib/cursor/resources/app/resources/helpers/cursorsandbox' "$PROFILE"
  grep -q 'profile cursor_sandbox_agent_worker' "$PROFILE"
  grep -q 'userns,' "$PROFILE"
  grep -q 'capability net_admin,' "$PROFILE"
  grep -q 'network netlink raw,' "$PROFILE"
  grep -q 'profile cursor_nix' "$PROFILE"
}

@test "install.sh is executable and refuses non-root" {
  [ -x "$INSTALL" ]
  run "$INSTALL"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must run as root"* ]]
}

@test "setup.sh invokes cursor-agent-sandbox install" {
  grep -q 'includes/cursor-agent-sandbox/install.sh' "$REPO_DIR/setup.sh"
}
