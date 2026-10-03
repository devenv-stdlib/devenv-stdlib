# Feature aspect: Cursor IDE package + desktop entry.
# Includes the extensions pack and LLM/MCP stack (enable → cascade DAG).
{ den, ... }:
let
  cascade = import ../den/_cascades/cursor-cascade.nix;
in
{
  den.aspects.cursor = {
    includes = map (name: den.aspects.${name}) cascade.cursor.includes;

    homeManager = {
      imports = [ ../../home/ides/cursor.nix ];
      # Inclusion is the enable switch for the Den path.
      cursor.enable = true;
    };
  };
}
