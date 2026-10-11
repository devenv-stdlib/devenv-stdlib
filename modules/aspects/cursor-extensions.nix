# Feature aspect: common Cursor extensions under ~/.cursor/extensions.
{ den, ... }:
let
  cascade = import ../den/_cascades/cursor-cascade.nix;
in
{
  den.aspects.cursor-extensions = {
    includes = map (name: den.aspects.${name}) cascade.cursor-extensions.includes;

    homeManager = {
      imports = [ ../../home/ides/cursor-extensions.nix ];
      # Option is defined by the cursor aspect; keep enable on when this runs alone in tests.
      cursor.enable = true;
    };
  };
}
