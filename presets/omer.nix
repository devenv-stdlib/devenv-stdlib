# Omer's default preset selection for generated monorepos.
# Attrpath refs only. Framework preset bodies stay in the devenv-stdlib flake input.
#
# HM includes below are cohesive bundles (quake XOR, ble.sh+atuin, ide any-of).
# Language tool presets live under presets/<lang>/<category>/ and are loaded by
# stdlib.devenv.load — each gated by `when = languages.<lang>.enable` from
# devenv.local.nix. Disable one building block with e.g.
# presets.python.lint.ruff.enable = false.
{ lib, ... }:
let
  inherit (import ../stdlib/preset.nix { inherit lib; }) mkPreset refsFromPaths;
  presets = refsFromPaths [
    [
      "terminal"
      "quake"
    ]
    [
      "terminal"
      "alacritty-atuin"
    ]
    [ "ide" ]
    [
      "host"
      "hm-only-guard"
    ]
  ];
in
{
  imports = [
    (mkPreset {
      path = [ "omer" ];
      description = "Presets this template enables by attrpath from devenv-stdlib";
      when = _: true;
      includes = with presets; [
        terminal.quake
        terminal.alacritty-atuin
        ide
        host.hm-only-guard
      ];
    })
  ];
}
