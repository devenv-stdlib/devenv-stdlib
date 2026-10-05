# build-cleaner preset: install the CLI for this repository (local) or the user
# profile via home-switch (global). Same file serves both loaders:
#   - stdlib.devenv.load passes `tools` → thin preset declaration
#   - Den / evalModules import without `tools` → mkPreset module
#
# Local wiring is a `module` config (mkIf), not a `project` function that
# reads config while applyPreset builds config (infinite recursion).
# No setup task: the binary is ready once it is on PATH.
args@{ lib, ... }:
let
  inherit (import ../../stdlib/preset.nix { inherit lib; }) mkPreset;
  toolLib = import ../../stdlib/tool.nix { inherit lib; };
  loadLib = import ../../stdlib/load.nix { inherit lib; };
  toolRefs = toolLib.refsFromSpecs (toolLib.specs (loadLib.discover [ ../../tools ]));

  scopeOption = lib.mkOption {
    type = lib.types.enum [
      "local"
      "global"
    ];
    default = "local";
    description = ''
      Where to enable build-cleaner.

      - `local` — this repository only (devenv module payload; package on PATH).
      - `global` — user profile via home-switch (Home Manager tool leaf).

      Matches mkTool local vs global vocabulary (catalog scopes use project/user).
    '';
  };

  # Package recipe lives on the tool leaf (install.package); prefer stubs in tests.
  bcPackage =
    (import ../../tools/cache/build-cleaner.nix {
      inherit lib;
      pkgs = { };
      config = { };
      __stdlibMeta = true;
    }).install.package;

  localModule =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.presets.cache.build-cleaner;
    in
    {
      options.presets.cache.build-cleaner.scope = scopeOption;
      config = lib.mkIf (cfg.enable && cfg.scope == "local") {
        packages = [ (bcPackage pkgs) ];
      };
    };

  # Thin (devenv): local install via module mkIf; no local mkTool leaf.
  thin = {
    path = [
      "cache"
      "build-cleaner"
    ];
    description = "build-cleaner — reclaim disk from build artifacts and caches (local or global).";
    defaultEnable = false;
    categoryPolicy = false;
    when = _: true;
    module = localModule;
    tools = [ ];
  };

  # Den / HM: only enable the global tool when scope=global.
  denModule = mkPreset {
    path = [
      "cache"
      "build-cleaner"
    ];
    description = "build-cleaner — reclaim disk from build artifacts and caches (local or global).";
    defaultEnable = false;
    when = _: true;
    policyId = false;
    extraOptions.scope = scopeOption;
    tools =
      cfg:
      lib.optional (
        (cfg.presets.cache.build-cleaner.scope or "local") == "global"
      ) toolRefs.cache.build-cleaner;
    configure =
      cfg:
      lib.optionalAttrs ((cfg.presets.cache.build-cleaner.scope or "local") == "global") {
        tools.build-cleaner.enable = true;
      };
  };
in
if args ? tools then
  thin
else
  {
    imports = [ denModule ];
  }
