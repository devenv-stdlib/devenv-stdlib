{ lib, ... }:
let
  pe = import <devenv4monorepo/tests/lib/preset-eval.nix> { inherit lib; };
  inherit (pe) eval shellLib;
  preset = import <devenv4monorepo/presets/cache/mr-boxington.nix>;

  denOptions = {
    options = {
      den = {
        aspects = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.raw;
          default = { };
        };
        policies = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.raw;
          default = { };
        };
      };
      tools = {
        bash.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        zsh.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        elvish.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        mr-boxington.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        build-cleaner.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };
      shell.preferred = shellLib.preferredOption;
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.anything;
        default = [ ];
      };
      warnings = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };

  denStub = {
    lib.policy = {
      include = value: {
        __policyEffect = "include";
        inherit value;
      };
      exclude = value: {
        __policyEffect = "exclude";
        inherit value;
      };
    };
    aspects = { };
  };

  evalCache =
    presetModule: extra:
    lib.evalModules {
      specialArgs.den = denStub;
      modules = [
        denOptions
        presetModule
        extra
      ];
    };

  toolEnableFromPresetAspect =
    presetFile: presetPath: toolName: extra:
    let
      presetEval = evalCache (import presetFile) extra;
      aspect = lib.getAttrFromPath (
        [
          "den"
          "aspects"
        ]
        ++ [ (lib.concatStringsSep "." presetPath) ]
      ) presetEval.config;
      hm = lib.evalModules {
        modules = [
          denOptions
          { config = aspect.homeManager; }
        ];
      };
    in
    {
      inherit (lib.getAttrFromPath ([ "presets" ] ++ presetPath) presetEval.config)
        enable
        scope
        ;
      inherit ((lib.getAttrFromPath ([ "presets" ] ++ presetPath) presetEval.config).result)
        applied
        includeTools
        ;
      toolEnable = hm.config.tools.${toolName}.enable;
    };
in
{
  testCacheMrBoxingtonPresetScopeGlobal = {
    expr =
      toolEnableFromPresetAspect <devenv4monorepo/presets/cache/mr-boxington.nix>
        [
          "cache"
          "mr-boxington"
        ]
        "mr-boxington"
        {
          presets.cache.mr-boxington.enable = true;
          presets.cache.mr-boxington.scope = "global";
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
