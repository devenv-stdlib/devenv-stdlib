{ lib, ... }:
let
  pe = import <devenv4monorepo/tests/lib/preset-eval.nix> { inherit lib; };
  inherit (pe) eval;
  preset = import <devenv4monorepo/presets/cache/mr-boxington.nix>;
in
{
  testCacheMrBoxingtonPresetScopeGlobal = {
    expr =
      let
        cfg =
          (eval preset {
            presets.cache.mr-boxington.enable = true;
            presets.cache.mr-boxington.scope = "global";
          }).config.presets.cache.mr-boxington;
      in
      {
        inherit (cfg) enable scope;
        inherit (cfg.result) applied includeTools;
        toolEnable = cfg.result.applied && builtins.elem "mr-boxington" cfg.result.includeTools;
      };
    expected = {
      enable = true;
      scope = "global";
      applied = true;
      includeTools = [ "mr-boxington" ];
      toolEnable = true;
    };
  };

  testCacheMrBoxingtonPresetScopeLocalSkipsGlobalTool = {
    expr =
      let
        cfg =
          (eval preset {
            presets.cache.mr-boxington.enable = true;
            presets.cache.mr-boxington.scope = "local";
          }).config.presets.cache.mr-boxington;
      in
      {
        inherit (cfg) enable scope;
        inherit (cfg.result) applied includeTools;
      };
    expected = {
      enable = true;
      scope = "local";
      applied = true;
      includeTools = [ ];
    };
  };

  testCacheMrBoxingtonPresetDefaultsOptInLocal = {
    expr =
      let
        cfg = (eval preset { }).config.presets.cache.mr-boxington;
      in
      {
        inherit (cfg) enable scope;
        inherit (cfg.result) applied includeTools;
      };
    expected = {
      enable = false;
      scope = "local";
      applied = false;
      includeTools = [ ];
    };
  };
}
