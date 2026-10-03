# Omer's default preset selection for generated monorepos.
# Names only. Framework preset bodies stay in the devenv-stdlib flake input.
# Language names stay gated by each preset's `when` (languages.<lang>.enable),
# which Copier writes in devenv.local.nix.
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
        "python"
        "rust"
        "go"
        "javascript"
        "typescript"
      ];
    })
  ];
}
