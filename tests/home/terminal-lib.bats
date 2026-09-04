#!/usr/bin/env bats
# Evaluates home/terminal-lib.nix. Does not run home-manager switch.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  EVAL="$REPO_DIR/tests/home/eval.nix"
}

@test "terminal-lib.nix maps keybindings, Warp TOML, and desktop entries" {
  if ! NIX_PATH="${NIX_PATH:-nixpkgs=flake:nixpkgs}" nix eval --impure --expr 'import <nixpkgs> { }' >/dev/null 2>&1; then
    skip "nixpkgs not on NIX_PATH"
  fi
  run env NIX_PATH="${NIX_PATH:-nixpkgs=flake:nixpkgs}" nix-instantiate --eval --strict "$EVAL"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}
