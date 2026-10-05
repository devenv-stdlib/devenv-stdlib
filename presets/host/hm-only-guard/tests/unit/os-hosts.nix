{ lib, ... }:
let
  pe = import <devenv4monorepo/tests/lib/preset-eval.nix> { inherit lib; };
  inherit (pe) eval sort;
in
{
  testHostHmOnlyGuardExcludesOsHostsOnly = {
    expr =
      let
        inherit
          ((eval (import <devenv4monorepo/presets/host/hm-only-guard.nix>) {
            presets.host.hm-only-guard.hostClass = "nixos";
            presets.host.hm-only-guard.selected = [ "terminal" ];
          }).config.presets.host.hm-only-guard
          )
          result
          ;
        banned = [
          "alacritty-quake"
          "terminal"
          "warp-quake"
        ];
      in
      {
        inherit (result) applied;
        nixos = sort (result.excludeAspects { host.class = "nixos"; });
        darwin = sort (result.excludeAspects { host.system = "aarch64-darwin"; });
        home = result.excludeAspects { };
        cousins = lib.intersectLists (result.excludeAspects { host.class = "darwin"; }) [
          "cursor"
          "zellij"
        ];
        coversSelected = result.applied && banned == sort (result.excludeAspects { host.class = "nixos"; });
      };
    expected = {
      applied = true;
      nixos = [
        "alacritty-quake"
        "terminal"
        "warp-quake"
      ];
      darwin = [
        "alacritty-quake"
        "terminal"
        "warp-quake"
      ];
      home = [ ];
      cousins = [ ];
      coversSelected = true;
    };
  };
}
