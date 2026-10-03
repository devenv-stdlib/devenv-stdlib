# Example composition only — not loaded by modules/devenv.nix.
# Shows how a consumer would assemble Python tool presets. The framework
# does not ship a megapreset named "python".
#
# Building blocks keep tool hierarchy via attrpaths (python.lint.ruff), not
# flat string literals:
#
#   mkPreset {
#     path = [ "my" "python" ];
#     includes = with presets; [
#       python.lint.ruff
#       python.hooks.check-python
#       python.hooks.debug-statements
#       python.hooks.sort-requirements-txt
#       python.type.pyright # or python.type.ty
#       python.serena
#       python.debtmap
#       python.ide
#       python.supported
#     ];
#   }
#
# With the devenv loader, the same building blocks are separate presets
# gated by `when = languages.python.enable`. Disable one with
# `presets.python.lint.ruff.enable = false` without dropping the rest.
{ lib, ... }:
let
  inherit (import ../../stdlib/preset.nix { inherit lib; }) mkPreset;
  devenvLoad = import ../../stdlib/devenv.nix { inherit lib; };
  presets = devenvLoad.refsOf (devenvLoad.defaultRoots ../.);
in
{
  imports = [
    (mkPreset {
      path = [
        "examples"
        "python"
      ];
      description = "Example user composition of Python tool presets (not a framework default).";
      when = cfg: (cfg.languages.python or { }).enable or false;
      includes = with presets; [
        python.lint.ruff
        python.hooks.check-python
        python.hooks.debug-statements
        python.hooks.sort-requirements-txt
        python.type.pyright
        python.serena
        python.debtmap
        python.ide
        python.supported
      ];
    })
  ];
}
