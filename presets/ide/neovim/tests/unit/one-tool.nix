{ lib, ... }:
let
  pe = import <devenv4monorepo/tests/lib/preset-eval.nix> { inherit lib; };
  inherit (pe) eval sort;
in
{
  testIdeNeovimPresetIsOneTool = {
    expr =
      let
        result =
          (eval (import <devenv4monorepo/presets/ide/neovim.nix>) { }).config.presets.ide.neovim.result;
      in
      {
        includeTools = sort result.includeTools;
        inherit (result) excludeTools;
      };
    expected = {
      includeTools = [ "neovim" ];
      excludeTools = [ ];
    };
  };
}
