# Cursor leaf. The package module is attached by stdlib.den.load
# (tools/ide/cursor.nix). This file keeps the cascade includes and the
# enable switch.
{ den, ... }:
let
  cascade = import ../den/_cascades/cursor-cascade.nix;
in
{
  den.aspects.cursor = {
    includes = map (name: den.aspects.${name}) cascade.cursor.includes;
    homeManager.cursor.enable = true;
  };
}
