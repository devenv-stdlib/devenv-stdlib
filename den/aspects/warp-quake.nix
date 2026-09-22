# Provider leaf: Warp dedicated hotkey window + GNOME custom keybinding.
# Mutual exclusion with alacritty-quake is enforced by terminal hub includes (XOR).
{ den, ... }:
let
  cascade = import ../terminal-cascade.nix;
in
{
  den.aspects.warp-quake = {
    includes = map (name: den.aspects.${name}) cascade.warp-quake.includes;

    homeManager = {
      imports = [ ../../home/terminal.nix ];
      terminal.provider = "warp";
    };
  };
}
