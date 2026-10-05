# mr-boxington preset: install mbx for this repository (local) or the user
# profile via home-switch (global). Same file serves both loaders:
#   - stdlib.devenv.load passes `tools` → thin preset declaration
#   - Den / evalModules import without `tools` → mkPreset module
#
# Local wiring is a `module` config (mkIf), not a `project` function that
# reads config while applyPreset builds config (infinite recursion).
# Note: `mbx setup --local` scopes the mise Cargo wrapper to the project, but
# may still write a user-level rust-analyzer check.overrideCommand (upstream).
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

      - `local` — this repository only (devenv module payload; `mbx setup --local`).
        Scopes the mise Cargo wrapper to the project; upstream may still write a
        user-level rust-analyzer override.
      - `global` — user profile via home-switch (Home Manager tool leaf;
        `mbx setup --global`).

      Matches mkTool local vs global vocabulary (catalog scopes use project/user).
    '';
  };

  # Package recipe lives on the tool leaf (install.package); prefer stubs in tests.
  mbxPackage =
    (import ../../tools/cache/mr-boxington.nix {
      inherit lib;
      pkgs = { };
      config = { };
      __stdlibMeta = true;
    }).install.package;

  mbxFor = pkgs: mbxPackage pkgs;

  # Store path when real package; plain name for unit-test stubs.
  mbxBin = mbx: if builtins.isAttrs mbx && mbx ? outPath then "${mbx}/bin/mbx" else "mbx";

  shimPathSnippet = ''
    if [ "$(uname -s)" = Darwin ]; then
      _mbx_shim="$HOME/Library/Application Support/mbx/bin"
    else
      _mbx_shim="$HOME/.local/share/mbx/bin"
    fi
    if [ -d "$_mbx_shim" ]; then
      export PATH="$_mbx_shim:$PATH"
    fi
    unset _mbx_shim
  '';

  localModule =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.presets.cache.mr-boxington;
      mbx = mbxFor pkgs;
    in
    {
      options.presets.cache.mr-boxington.scope = scopeOption;
      config = lib.mkIf (cfg.enable && cfg.scope == "local") {
        packages = [ mbx ];
        tasks."mr-boxington:setup" = {
          exec = ''
            set -euo pipefail
            if ! ${mbxBin mbx} setup --local; then
              echo "mr-boxington: mbx setup --local failed (continuing)" >&2
            fi
          '';
          after = [ "mise:install" ];
        };
        tasks."devenv:enterShell".after = [ "mr-boxington:setup" ];
        enterShell = shimPathSnippet;
      };
    };

  # Thin (devenv): local install via module mkIf; no local mkTool leaf.
  thin = {
    path = [
      "cache"
      "mr-boxington"
    ];
    description = "mr-boxington (mbx) Cargo build cache — repository-local or user-global.";
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
    configure =
      cfg:
      lib.optionalAttrs ((cfg.presets.cache.mr-boxington.scope or "local") == "global") {
        tools.mr-boxington.enable = true;
      };
  };
in
if args ? tools then
  thin
else
  {
    imports = [ denModule ];
  }
