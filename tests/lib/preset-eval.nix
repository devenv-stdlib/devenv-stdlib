# Shared mkPreset eval helpers for per-preset unit suites.
{ lib }:
let
  presetLib = import ../../stdlib/preset.nix { inherit lib; };
  shellLib = import ../../stdlib/shell.nix { inherit lib; };

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
      };
      shell.preferred = shellLib.preferredOption;
    };
  };

  eval =
    presetModule: extra:
    lib.evalModules {
      specialArgs.den = denStub;
      modules = [
        denOptions
        presetModule
        extra
      ];
    };

  withBash = {
    tools.bash.enable = true;
  };

  sort = names: lib.sort (a: b: a < b) names;
in
{
  inherit
    lib
    presetLib
    shellLib
    eval
    withBash
    sort
    ;
}
