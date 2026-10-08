# Production defaultRoots plus tools/, the module set modules/devenv.nix
# loads for `devenv shell`. Host options are the devenv surface that loader
# writes (assertions, enterShell, files, …). Forces preset realize.
{
  lib,
  ...
}:
let
  devenv = import ../../stdlib/devenv.nix { inherit lib; };
  pkgs = import <nixpkgs> { };
  supported = import ../../stdlib/devenv-supported.nix;
  enableOpt = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
  host = {
    options = {
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
      name = lib.mkOption {
        type = lib.types.str;
        default = "devenv-shell";
      };
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
      scripts = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.anything;
        default = { };
      };
      files = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.anything;
        default = { };
      };
      git-hooks = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.anything;
        default = { };
      };
      treefmt = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.anything;
        default = { };
      };
      processes = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.anything;
        default = { };
      };
      languages = lib.genAttrs supported.languages (_: enableOpt);
      services = lib.genAttrs supported.services (_: enableOpt);
    };
  };
  cfg =
    (lib.evalModules {
      modules = [
        {
          _module.args.pkgs = pkgs;
        }
        host
      ]
      ++ devenv.load {
        presets = devenv.defaultRoots ../../presets;
        tools = [ ../../tools ];
      };
    }).config;
in
{
  testDevenvShellLoadsDefaultPresets = {
    expr = {
      provider = cfg.presets.terminal.quake.provider;
      quakeApplied = cfg.presets.terminal.quake.result.applied;
      atuinApplied = cfg.presets.terminal.alacritty-atuin.result.applied;
      hostApplied = cfg.presets.host.hm-only-guard.result.applied;
    };
    expected = {
      provider = "alacritty";
      quakeApplied = true;
      atuinApplied = false;
      hostApplied = true;
    };
  };
}
