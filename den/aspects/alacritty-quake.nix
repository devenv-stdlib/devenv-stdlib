# Provider leaf: Alacritty + Zellij + Quake GNOME extension.
# Mutual exclusion with warp-quake is enforced by terminal hub includes (XOR).
{ den, ... }:
let
  cascade = import ../terminal-cascade.nix;
in
{
  den.aspects.alacritty-quake = {
    includes = map (name: den.aspects.${name}) cascade.alacritty-quake.includes;

    homeManager = {
      # Shared terminal.nix still imports alacritty.nix behind mkIf (shim).
      # Setting provider makes the include → install edge explicit for Den path.
      imports = [ ../../home/terminal.nix ];
      terminal.provider = "alacritty";
    };
  };
}
