#!/usr/bin/env bats
# Phase 2 W2.1: Den terminal includes cascade + provider XOR eval.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  EVAL="$REPO_DIR/tests/home/den-terminal-eval.nix"
}

@test "den terminal cascade metadata documents XOR" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --json "$REPO_DIR#denTerminalCascade"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'alacritty-quake'
  echo "$output" | grep -q 'warp-quake'
  echo "$output" | grep -q 'xorProviders'
}

@test "den homeConfigurationsWarp.developer exists" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --expr "builtins.hasAttr \"developer\" (builtins.getFlake \"${REPO_DIR}\").homeConfigurationsWarp"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "den alacritty vs warp homeConfiguration providers" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix-instantiate --eval --strict --impure "$EVAL"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}
