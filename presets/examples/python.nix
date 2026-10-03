# Example composition only — not loaded by modules/devenv.nix.
# Shows how a consumer would assemble Python tool presets. The framework
# does not ship a megapreset named "python".
#
# In a consumer flake (Den / mkPreset style):
#
#   mkPreset {
#     name = "my-python";
#     includes = [
#       "ruff"
#       "check-python"
#       "python-debug-statements"
#       "sort-requirements-txt"
#       "pyright" # or "ty"
#       "serena-python"
#       "debtmap-python"
#       "python-ide"
#       "python-supported"
#     ];
#   }
#
# With the devenv loader, the same building blocks are separate presets
# gated by `when = languages.python.enable`. Disable one with
# `presets.ruff.enable = false` without dropping the rest.
{ lib, ... }:
let
  inherit (import ../../stdlib/preset.nix { inherit lib; }) mkPreset;
in
{
  imports = [
    (mkPreset {
      name = "example-python";
      description = "Example user composition of Python tool presets (not a framework default).";
      when = cfg: (cfg.languages.python or { }).enable or false;
      includes = [
        "ruff"
        "check-python"
        "python-debug-statements"
        "sort-requirements-txt"
        "pyright"
        "serena-python"
        "debtmap-python"
        "python-ide"
        "python-supported"
      ];
    })
  ];
}
