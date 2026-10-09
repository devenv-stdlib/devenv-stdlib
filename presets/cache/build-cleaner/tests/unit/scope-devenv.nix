# devenv loader coverage for cache.build-cleaner local/global scope.
{ lib, ... }:
let
  devenvLoad = import <devenv4monorepo/stdlib/devenv.nix> { inherit lib; };

  freeform = lib.types.submodule {
    freeformType = lib.types.lazyAttrsOf lib.types.anything;
  };

  fixtureOptions = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "fixture";
    };
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
    };
    assertions = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
    };
    warnings = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    enterShell = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };
    tasks = lib.mkOption {
      type = freeform;
      default = { };
    };
    # Present so assertions can read tools.<leaf>.enable without loading
    # every local tool module into this fixture.
    tools = lib.mkOption {
      type = freeform;
      default = { };
    };
    # devenv.load always imports `lower` (serena / vscode files + sync scripts).
    files = lib.mkOption {
      type = lib.types.attrsOf freeform;
      default = { };
    };
    scripts = lib.mkOption {
      type = lib.types.attrsOf freeform;
      default = { };
    };
  };

  eval =
    extra:
    (lib.evalModules {
      modules = [
        {
          _module.args.pkgs = {
            build-cleaner = "build-cleaner-fixture";
          };
        }
        {
          options = fixtureOptions;
          config = extra;
        }
      ]
      ++ devenvLoad.load {
        presets = [ <devenv4monorepo/presets/cache> ];
        tools = [ ];
      };
    }).config;
in
{
  testCacheBuildCleanerLocalEnablesPackage = {
    expr =
      let
        cfg = eval {
          presets.cache.build-cleaner.enable = true;
          presets.cache.build-cleaner.scope = "local";
        };
        result = cfg.presets.cache.build-cleaner.result;
      in
      {
        inherit (cfg.presets.cache.build-cleaner) enable scope;
        inherit (result) applied includeTools;
        tool = (cfg.tools.build-cleaner or { }).enable or false;
        hasPackage = builtins.elem "build-cleaner-fixture" cfg.packages;
        hasDryRunTask = cfg.tasks ? "build-cleaner:dry-run";
      };
    expected = {
      enable = true;
      scope = "local";
      applied = true;
      includeTools = [ ];
      tool = false;
      hasPackage = true;
      hasDryRunTask = true;
    };
  };

  testCacheBuildCleanerGlobalSkipsLocalPackage = {
    expr =
      let
        cfg = eval {
          presets.cache.build-cleaner.enable = true;
          presets.cache.build-cleaner.scope = "global";
        };
        result = cfg.presets.cache.build-cleaner.result;
      in
      {
        inherit (cfg.presets.cache.build-cleaner) enable scope;
        inherit (result) applied includeTools;
        tool = (cfg.tools.build-cleaner or { }).enable or false;
        hasPackage = builtins.elem "build-cleaner-fixture" cfg.packages;
      };
    expected = {
      enable = true;
      scope = "global";
      applied = true;
      includeTools = [ ];
      tool = false;
      hasPackage = false;
    };
  };

  testCacheBuildCleanerDefaultsOff = {
    expr =
      let
        cfg = eval { };
      in
      {
        enable = cfg.presets.cache.build-cleaner.enable;
        scope = cfg.presets.cache.build-cleaner.scope;
        tool = (cfg.tools.build-cleaner or { }).enable or false;
        applied = cfg.presets.cache.build-cleaner.result.applied;
        hasPackage = builtins.elem "build-cleaner-fixture" cfg.packages;
      };
    expected = {
      enable = false;
      scope = "local";
      tool = false;
      applied = false;
      hasPackage = false;
    };
  };
}
