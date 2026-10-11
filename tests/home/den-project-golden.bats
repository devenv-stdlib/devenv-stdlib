#!/usr/bin/env bats
# Phase 4: Den/project goldens for python-on fixture + project class resolve.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "denProjectGolden flake export reports match" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --json "$REPO_DIR#denProjectGolden.match"
  [ "$status" -eq 0 ]
  [[ "$output" == *true* ]]
}

@test "den project class is registered" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --json "$REPO_DIR#denProjectClass.registered"
  [ "$status" -eq 0 ]
  [[ "$output" == *true* ]]
}

@test "den project class resolve yields python leaf concerns" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --json "$REPO_DIR#denProjectClass.pythonLeafConcerns"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'hooks'
  echo "$output" | grep -q 'ide-recs'
  echo "$output" | grep -q 'serena'
  echo "$output" | grep -q 'debtmap'
}
