# Omer's default preset selection for generated monorepos.
# Names only. Framework preset bodies stay in the devenv-stdlib flake input.
#
# HM includes below are cohesive bundles (quake XOR, ble.sh+atuin, ide any-of).
# Language tool presets live under presets/lang/<lang>/ and are loaded by
# stdlib.devenv.load — each gated by `when = languages.<lang>.enable` from
# devenv.local.nix. There is no framework megapreset named python/rust/….
# Disable one building block with e.g. presets.ruff.enable = false.
{ lib, ... }:
let
  inherit (import ../stdlib/preset.nix { inherit lib; }) mkPreset;
in
{
  imports = [
    (mkPreset {
      name = "omer";
      description = "Presets this template enables by name from devenv-stdlib";
      when = _: true;
      includes = [
        "terminal-quake"
        "alacritty-atuin"
        "ide"
        "host-hm-only-guard"
      ];
    })
  ];
}
