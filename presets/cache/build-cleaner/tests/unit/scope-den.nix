{ lib, ... }:
let
  pe = import <devenv4monorepo/tests/lib/preset-eval.nix> { inherit lib; };
  inherit (pe) eval shellLib;
  preset = import <devenv4monorepo/presets/cache/build-cleaner.nix>;

  # Tip stdlib-presets denOptions extras for cache tools + HM payload merge.
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
        build-cleaner.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        mr-boxington.enable = lib.mkOption {
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

  evalCache =
    presetModule: extra:
    lib.evalModules {
      specialArgs.den =
        pe.denStub or {
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
      modules = [
        denOptions
        presetModule
        extra
      ];
    };

  # pe.eval may lack cache tool options; use local evalCache for aspect HM checks.
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
  testCacheBuildCleanerPresetScopeGlobal = {
    expr =
      toolEnableFromPresetAspect <devenv4monorepo/presets/cache/build-cleaner.nix>
        [
          "cache"
          "build-cleaner"
        ]
        "build-cleaner"
        {
          presets.cache.build-cleaner.enable = true;
          presets.cache.build-cleaner.scope = "global";
        };
    expected = {
      enable = true;
      scope = "global";
      applied = true;
      includeTools = [ "build-cleaner" ];
      toolEnable = true;
    };
  };

  testCacheBuildCleanerPresetLocalConfigureLeavesToolOff = {
    expr =
      toolEnableFromPresetAspect <devenv4monorepo/presets/cache/build-cleaner.nix>
        [
          "cache"
          "build-cleaner"
        ]
        "build-cleaner"
        {
          presets.cache.build-cleaner.enable = true;
          presets.cache.build-cleaner.scope = "local";
        };
    expected = {
      enable = true;
      scope = "local";
      applied = true;
      includeTools = [ ];
      toolEnable = false;
    };
  };

  testCacheBuildCleanerPresetScopeLocalSkipsGlobalTool = {
    expr =
      let
        cfg =
          (eval preset {
            presets.cache.build-cleaner.enable = true;
            presets.cache.build-cleaner.scope = "local";
          }).config.presets.cache.build-cleaner;
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

  testCacheBuildCleanerPresetDefaultsOptInLocal = {
    expr =
      let
        cfg = (eval preset { }).config.presets.cache.build-cleaner;
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
