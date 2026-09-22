#!/usr/bin/env bats
# Phase 3: dual HM path — Den homeConfiguration ≡ legacy home.nix fingerprints.
# Eval goldens are the merge bar; full dual switch is nice-to-have.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  EVAL="$REPO_DIR/tests/home/den-hm-parity-eval.nix"
}

@test "denHmParity flake export reports match" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --json "$REPO_DIR#denHmParity.match"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "den vs legacy HM fingerprint eval asserts" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix-instantiate --eval --strict --impure "$EVAL"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "legacy home.nix and Den developer homeConfiguration both exist" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  [ -f "$REPO_DIR/home.nix" ]
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --expr "builtins.hasAttr \"developer\" (builtins.getFlake \"${REPO_DIR}\").homeConfigurations"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}
