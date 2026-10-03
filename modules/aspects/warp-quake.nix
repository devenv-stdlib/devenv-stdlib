# Provider leaf. The Warp HM module is the generated warp tool aspect.
{ den, ... }:
let
  cascade = import ../den/_cascades/terminal-cascade.nix;
in
{
  den.aspects.warp-quake = {
    includes = map (name: den.aspects.${name}) (cascade.warp-quake.includes ++ [ "warp" ]);
    homeManager = {
      imports = [ ../../home/terminal.nix ];
      terminal.provider = "warp";
    };
  };
}
