#!/usr/bin/env bats
# Phase 1: Den cursor includes cascade + homeConfiguration option dump.
# Prefers eval/option checks over full home-manager switch / GUI.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  EVAL="$REPO_DIR/tests/home/den-cursor-eval.nix"
}

@test "den cursor cascade metadata matches aspect includes" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --json "$REPO_DIR#denCursorCascade"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'cursor-extensions'
  echo "$output" | grep -q 'cursor-llm'
}

@test "den homeConfigurations.developer exists (cursor-on path)" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --expr "builtins.hasAttr \"developer\" (builtins.getFlake \"${REPO_DIR}\").homeConfigurations"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "den cursor-on vs cursor-off homeConfiguration options" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  # Full HM option dump — may download nixpkgs/HM/den on first run.
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix-instantiate --eval --strict --impure "$EVAL"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}
