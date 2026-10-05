# home.local.nix path: HM-side cache preset bridge (home/cache-presets.nix).
{ lib, ... }:
let
  evalHmCachePresets =
    extra:
    lib.evalModules {
      modules = [
        {
          options.tools = {
            mr-boxington.enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            build-cleaner.enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
          };
        }
        (import <devenv4monorepo/home/cache-presets.nix>)
        extra
      ];
    };
in
{
  testHmCachePresetsBuildCleanerGlobalEnablesTool = {
    expr =
      let
        cfg =
          (evalHmCachePresets {
            presets.cache.build-cleaner.enable = true;
            presets.cache.build-cleaner.scope = "global";
          }).config;
      in
      {
        inherit (cfg.presets.cache.build-cleaner) enable scope;
        tool = cfg.tools.build-cleaner.enable;
        sibling = cfg.tools.mr-boxington.enable;
      };
    expected = {
      enable = true;
      scope = "global";
      tool = true;
      sibling = false;
    };
  };

  testHmCachePresetsBuildCleanerLocalLeavesToolOff = {
    expr =
      let
        cfg =
          (evalHmCachePresets {
            presets.cache.build-cleaner.enable = true;
            presets.cache.build-cleaner.scope = "local";
          }).config;
      in
      {
        inherit (cfg.presets.cache.build-cleaner) enable scope;
        tool = cfg.tools.build-cleaner.enable;
      };
    expected = {
      enable = true;
      scope = "local";
      tool = false;
    };
  };

  testHmCachePresetsMrBoxingtonGlobalEnablesTool = {
    expr =
      let
        cfg =
          (evalHmCachePresets {
            presets.cache.mr-boxington.enable = true;
            presets.cache.mr-boxington.scope = "global";
          }).config;
      in
      {
        inherit (cfg.presets.cache.mr-boxington) enable scope;
        tool = cfg.tools.mr-boxington.enable;
      };
    expected = {
      enable = true;
      scope = "global";
      tool = true;
    };
  };

  testHmCachePresetsDefaultsOff = {
    expr =
      let
        cfg = (evalHmCachePresets { }).config;
      in
      {
        bc = {
          inherit (cfg.presets.cache.build-cleaner) enable scope;
        };
        mbx = {
          inherit (cfg.presets.cache.mr-boxington) enable scope;
        };
        tools = {
          build-cleaner = cfg.tools.build-cleaner.enable;
          mr-boxington = cfg.tools.mr-boxington.enable;
        };
      };
    expected = {
      bc = {
        enable = false;
        scope = "local";
      };
      mbx = {
        enable = false;
        scope = "local";
      };
      tools = {
        build-cleaner = false;
        mr-boxington = false;
      };
    };
  };
}
