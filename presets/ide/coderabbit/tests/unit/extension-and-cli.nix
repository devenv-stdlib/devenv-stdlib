{ lib, ... }:
let
  pe = import <devenv4monorepo/tests/lib/preset-eval.nix> { inherit lib; };
  inherit (pe) eval sort;
in
{
  testIdeCoderabbitPresetIsExtensionAndCli = {
    expr =
      let
        inherit
          ((eval (import <devenv4monorepo/presets/ide/coderabbit.nix>) { }).config.presets.ide.coderabbit)
          result
          ;
      in
      {
        includeTools = sort result.includeTools;
        inherit (result) excludeTools applied;
      };
    expected = {
      includeTools = [
        "coderabbit"
        "coderabbit-cli"
      ];
      excludeTools = [ ];
      applied = true;
    };
  };
}
