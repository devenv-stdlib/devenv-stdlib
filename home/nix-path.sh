#!/usr/bin/env bash
# Flakes-only hosts often have no <nixpkgs> on NIX_PATH; home-manager -f
# needs it. Keep a user-supplied nixpkgs= entry; otherwise prepend
# nixpkgs=flake:nixpkgs. Drop absolute entries that do not exist (for
# example ~/.nix-defexpr/channels without channels): Nix warns about each
# one on every evaluation. Sourced by setup.sh, home-switch, test-devenv.

ensure_nixpkgs_on_nix_path() {
  local rest entry kept="" has_nixpkgs=0
  rest=${NIX_PATH:-}
  while [[ -n $rest ]]; do
    entry=${rest%%:*}
    rest=${rest#"$entry"}
    rest=${rest#:}
    case $entry in
      nixpkgs=*) has_nixpkgs=1 ;;
      /*) [[ -e $entry ]] || continue ;;
    esac
    kept="${kept:+$kept:}$entry"
  done
  if [[ $has_nixpkgs -eq 0 ]]; then
    kept="nixpkgs=flake:nixpkgs${kept:+:$kept}"
  fi
  export NIX_PATH=$kept
}
