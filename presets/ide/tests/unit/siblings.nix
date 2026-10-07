{ lib, ... }:
let
  pe = import <devenv4monorepo/tests/lib/preset-eval.nix> { inherit lib; };
  inherit (pe) eval sort;
in
{
  testIdePresetDoesNotExcludeSiblingIdes = {
    expr =
      let
        inherit ((eval (import <devenv4monorepo/presets/ide/default.nix>) { }).config.presets.ide) result;
      in
      {
        includeTools = sort result.includeTools;
        inherit (result) excludeTools;
      };
    expected = {
      includeTools = [
        "cursor"
        "neovim"
        "vscode"
      ];
      excludeTools = [ ];
    };
  };
}
