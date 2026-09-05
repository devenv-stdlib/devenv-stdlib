# nix-unit suite. Import with: nix-unit tests/unit/default.nix
let
  lib = import <nixpkgs/lib>;
  harness = import ./harness.nix { inherit lib; };
in
(import ./versions.nix harness)
// (import ./problems.nix harness)
// (import ./matrices.nix harness)
// (import ./workflow.nix harness)
// (import ./hooks.nix harness)
// (import ./cursor.nix harness)
// (import ./terminal.nix harness)
