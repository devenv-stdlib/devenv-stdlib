# Main nix-unit suite: stdlib, Den aspects, and other cross-cutting topics.
# Per-tool / per-preset suites live under tools/**/tests/unit and presets/**/tests/unit
# and are discovered by test-devenv-unit (see tests/lib/discover-suites.nix).
# Import with: nix-unit -I devenv4monorepo=$PWD tests/unit/default.nix
let
  lib = import <nixpkgs/lib>;
  suite = import ../lib/suite.nix { inherit lib; };
  inherit (suite) mergeTests;
in
lib.foldl' (acc: dir: mergeTests (toString dir) acc (suite.load dir)) { } [
  ./.
  ./stdlib
  ./aspects
]
