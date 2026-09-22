# Feature aspect: terminal hub (Starship + GNOME sync + provider selection).
# Includes exactly one provider aspect (alacritty-quake XOR warp-quake).
# Phase 5: Ubuntu/GNOME-only — no nixos/darwin class keys (see den/MULTI-OS.md).
{ den, ... }:
let
  cascade = import ../terminal-cascade.nix;
in
{
  den.aspects.terminal = {
    includes = map (name: den.aspects.${name}) cascade.terminal.includes;

    homeManager = {
      imports = [ ../../home/terminal.nix ];
      # Default matches cascade.terminal.includes → alacritty-quake.
      terminal.provider = "alacritty";
    };
  };
}
