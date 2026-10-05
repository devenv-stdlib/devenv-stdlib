{ lib, ... }:
let
  pe = import <devenv4monorepo/tests/lib/preset-eval.nix> { inherit lib; };
  inherit (pe) eval sort;
in
{
  testTerminalQuakeExcludeStaysOnTerminalNode = {
    expr =
      let
        inherit
          ((eval (import <devenv4monorepo/presets/terminal/quake.nix>) { }).config.presets.terminal.quake)
          result
          ;
      in
      {
        inherit (result) includeTools;
        excludeTools = sort result.excludeTools;
        excludeAspects = sort (result.excludeAspects { });
        includeAspects = sort result.includeAspects;
        crosses = lib.intersectLists result.excludeTools [
          "zellij"
          "atuin"
          "cursor"
        ];
      };
    expected = {
      includeTools = [ "alacritty" ];
      excludeTools = [ "warp" ];
      excludeAspects = [ "warp" ];
      includeAspects = [ "alacritty" ];
      crosses = [ ];
    };
  };
}
