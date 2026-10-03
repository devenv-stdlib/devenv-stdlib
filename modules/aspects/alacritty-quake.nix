# Provider leaf: Alacritty + Zellij + Quake GNOME extension.
# Mutual exclusion with warp-quake is enforced by terminal hub includes (XOR).
# Phase 5: unsupported on darwin/nixos — HM-only (no OS class keys).
{ den, ... }:
let
  cascade = import ../den/_cascades/terminal-cascade.nix;
in
{
  den.aspects.alacritty-quake = {
    includes = map (name: den.aspects.${name}) cascade.alacritty-quake.includes;

    homeManager = {
      # Shared terminal.nix still imports alacritty.nix behind mkIf.
      # Setting provider makes the include → install edge explicit for Den path.
      imports = [ ../../home/terminal.nix ];
      terminal.provider = "alacritty";
    };
  };
}
