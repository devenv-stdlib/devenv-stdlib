# Per-owner nix-unit suite. Discovered by tests/lib/discover-suites.nix.
let
  lib = import <nixpkgs/lib>;
  suite = import <devenv4monorepo/tests/lib/suite.nix> { inherit lib; };
in
suite.load ./.
