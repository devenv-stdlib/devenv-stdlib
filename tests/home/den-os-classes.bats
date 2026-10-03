#!/usr/bin/env bats
# Phase 5: den.hosts / OS class eval matrix + Ubuntu Den path still present.

# `run --separate-stderr`: Nix logs fetch progress and fetcher-lock waits on
# stderr; these tests compare the eval result on stdout verbatim.
bats_require_minimum_version 1.5.0

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "denOsClasses flake export reports match" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run --separate-stderr env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --json "$REPO_DIR#denOsClasses.match"
  [ "$status" -eq 0 ]
  [[ "$output" == *true* ]]
}

@test "den hosts matrix has nixos and darwin stub classes" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run --separate-stderr env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --json "$REPO_DIR#denOsClasses.hosts"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"class\":\"nixos\""* ]] || [[ "$output" == *"\"class\": \"nixos\""* ]]
  [[ "$output" == *"\"class\":\"darwin\""* ]] || [[ "$output" == *"\"class\": \"darwin\""* ]]
}

@test "ubuntu-only quake aspects have no nixos/darwin keys" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  # Documented unsupported on Darwin/NixOS (GNOME quake) — assert-absent, not silent.
  run --separate-stderr env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --json "$REPO_DIR#denOsClasses.ubuntuOnlyGuards.alacritty-quake.hasNixos"
  [ "$status" -eq 0 ]
  [[ "$output" == *false* ]]
  run --separate-stderr env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --json "$REPO_DIR#denOsClasses.ubuntuOnlyGuards.warp-quake.hasDarwin"
  [ "$status" -eq 0 ]
  [[ "$output" == *false* ]]
}

@test "Ubuntu Den developer homeConfiguration still exists" {
  if ! command -v nix >/dev/null 2>&1; then
    skip "nix not installed"
  fi
  run --separate-stderr env NIX_CONFIG="experimental-features = nix-command flakes" \
    nix eval --impure --expr "builtins.hasAttr \"developer\" (builtins.getFlake \"${REPO_DIR}\").homeConfigurations"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "MULTI-OS docs mention unsupported quake" {
  grep -qi 'quake' "$REPO_DIR/den/MULTI-OS.md"
  grep -qi 'unsupported' "$REPO_DIR/den/MULTI-OS.md"
}
