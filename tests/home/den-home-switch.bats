#!/usr/bin/env bats
# Phase 4: Den-only HM path — home-switch → flake #developer; Den goldens.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  EVAL="$REPO_DIR/tests/home/den-hm-golden-eval.nix"
}

@test "denHmGolden flake export reports match" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --json "$REPO_DIR#denHmGolden.match"
  [ "$status" -eq 0 ]
  # nix may print dirty-tree warnings before the JSON value (no trailing newline).
  [[ "$output" == *true* ]]
}

@test "den HM golden eval asserts" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix-instantiate --eval --strict --impure "$EVAL"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "home-switch script is Den flake-only" {
  grep -qE 'home-manager switch -b backup --flake .*#developer.*--impure' "$REPO_DIR/devenv.nix"
  ! grep -q 'home-switch-den' "$REPO_DIR/devenv.nix"
  ! grep -qE 'home-manager switch .* -f .*home\.nix' "$REPO_DIR/devenv.nix"
}

@test "Den developer homeConfiguration exists" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --expr "builtins.hasAttr \"developer\" (builtins.getFlake \"${REPO_DIR}\").homeConfigurations"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}
