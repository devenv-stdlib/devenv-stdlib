# mr-boxington preset: install mbx for this repository (local) or the user
# profile via home-switch (global). Same file serves both loaders:
#   - stdlib.devenv.load passes `tools` → thin preset declaration
#   - Den / evalModules import without `tools` → mkPreset module
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
      Where to enable mr-boxington (mbx).

      - `local` — this repository only (devenv / project payload; `mbx setup --local`).
      - `global` — user profile via home-switch (Home Manager payload; `mbx setup --global`).

      Matches mkTool local vs global vocabulary (catalog scopes use project/user).
    '';
  };

  # Thin (devenv): only enable the dual-scope tool when scope=local.
  thin = {
    path = [
      "cache"
      "mr-boxington"
    ];
    description = "mr-boxington (mbx) Cargo build cache — repository-local or user-global.";
    # Opt-in; category is unbound so Rust need not be enabled first.
    defaultEnable = false;
    categoryPolicy = false;
    when = _: true;
    module = {
      options.presets.cache.mr-boxington.scope = scopeOption;
    };
    tools =
      cfg:
      lib.optional (
        (cfg.presets.cache.mr-boxington.scope or "local") == "local"
      ) toolRefs.cache.mr-boxington;
  };

  # Den / HM: only enable the tool when scope=global.
  denModule = mkPreset {
    path = [
      "cache"
      "mr-boxington"
    ];
    description = "mr-boxington (mbx) Cargo build cache — repository-local or user-global.";
    defaultEnable = false;
    when = _: true;
    policyId = false;
    extraOptions.scope = scopeOption;
    tools =
      cfg:
      lib.optional (
        (cfg.presets.cache.mr-boxington.scope or "local") == "global"
      ) toolRefs.cache.mr-boxington;
    # Tool defaultEnable is false; Den includeAspects alone does not flip it.
    configure =
      cfg:
      lib.optionalAttrs ((cfg.presets.cache.mr-boxington.scope or "local") == "global") {
        tools.mr-boxington.enable = true;
      };
  };
in
# devenv.loadEntry imports with `{ lib, tools }`.
if args ? tools then
  thin
else
  {
    imports = [ denModule ];
  }
