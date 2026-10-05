# devenv loader coverage for cache.mr-boxington local/global scope.
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
            # Stub avoids fetchurl in unit eval.
            mr-boxington = "mbx-fixture";
          };
        }
        {
          options = fixtureOptions;
          config = extra;
        }
      ]
      # Cache tool specs needed so exportTasks can resolve declared leaves
      # (global binary leaves are not loaded as local modules).
      ++ devenvLoad.load {
        presets = [ <devenv4monorepo/presets/cache> ];
        tools = [ <devenv4monorepo/tools/cache> ];
      };
    }).config;
in
{
  # cache.mr-boxington: local scope installs via preset project payload (not a local tool leaf).
  testCacheMrBoxingtonLocalEnablesTool = {
    expr =
      let
        cfg = eval {
          presets.cache.mr-boxington.enable = true;
          presets.cache.mr-boxington.scope = "local";
        };
        result = cfg.presets.cache.mr-boxington.result;
      in
      {
        inherit (cfg.presets.cache.mr-boxington) enable scope;
        inherit (result) applied includeTools;
        # Global mkTool leaf is not loaded into devenv (HM-only).
        tool = (cfg.tools.mr-boxington or { }).enable or false;
        hasSetupTask = cfg.tasks ? "mr-boxington:setup";
        hasDoctorTask = cfg.tasks ? "mr-boxington:doctor";
        hasGcTask = cfg.tasks ? "mr-boxington:gc";
        hasStatsTask = cfg.tasks ? "mr-boxington:stats";
        hasPackage = builtins.elem "mbx-fixture" cfg.packages;
      };
    expected = {
      enable = true;
      scope = "local";
      applied = true;
      includeTools = [ ];
      tool = false;
      hasSetupTask = true;
      hasDoctorTask = true;
      hasGcTask = true;
      hasStatsTask = true;
      hasPackage = true;
    };
  };

  # cache.mr-boxington: global scope is a no-op in devenv (HM/home-switch owns it).
  testCacheMrBoxingtonGlobalSkipsLocalTool = {
    expr =
      let
        cfg = eval {
          presets.cache.mr-boxington.enable = true;
          presets.cache.mr-boxington.scope = "global";
        };
        result = cfg.presets.cache.mr-boxington.result;
      in
      {
        inherit (cfg.presets.cache.mr-boxington) enable scope;
        inherit (result) applied includeTools;
        tool = (cfg.tools.mr-boxington or { }).enable or false;
        hasSetupTask = cfg.tasks ? "mr-boxington:setup";
        hasPackage = builtins.elem "mbx-fixture" cfg.packages;
      };
    expected = {
      enable = true;
      scope = "global";
      applied = true;
      includeTools = [ ];
      tool = false;
      hasSetupTask = false;
      hasPackage = false;
    };
  };

  testCacheMrBoxingtonDefaultsOff = {
    expr =
      let
        cfg = eval { };
      in
      {
        enable = cfg.presets.cache.mr-boxington.enable;
        scope = cfg.presets.cache.mr-boxington.scope;
        tool = (cfg.tools.mr-boxington or { }).enable or false;
        applied = cfg.presets.cache.mr-boxington.result.applied;
        hasSetupTask = cfg.tasks ? "mr-boxington:setup";
      };
    expected = {
      enable = false;
      scope = "local";
      tool = false;
      applied = false;
      hasSetupTask = false;
    };
  };
}
