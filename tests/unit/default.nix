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
// (import ./debtmap.nix harness)
// (import ./vscode.nix harness)
// (import ./serena.nix harness)
// (import ./terminal.nix harness)
// (import ./non-nix.nix harness)
// (import ./den-cursor.nix harness)
// (import ./den-terminal.nix harness)
// (import ./den-python.nix harness)
// (import ./den-languages.nix harness)
// (import ./den-ide.nix harness)
// (import ./den-hm-parity.nix harness)
// (import ./den-project-parity.nix harness)
// (import ./den-project-class.nix harness)
