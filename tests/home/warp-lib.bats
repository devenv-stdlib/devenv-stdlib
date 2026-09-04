#!/usr/bin/env bats
# Evaluates home/warp-lib.nix. Does not run home-manager switch or launch Warp.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  EVAL="$REPO_DIR/tests/home/eval.nix"
}

@test "warp-lib.nix maps keybindings and settings.toml" {
  if ! nix eval --impure --expr 'import <nixpkgs> { }' >/dev/null 2>&1; then
    skip "nixpkgs not on NIX_PATH"
  fi
  run nix-instantiate --eval --strict "$EVAL"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}
