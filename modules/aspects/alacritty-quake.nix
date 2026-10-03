# Provider leaf. HM modules come from the generated tool aspects
# (alacritty, zellij, atuin, blesh). terminal.nix still owns provider
# options and the GNOME dash sync until presets land.
{ den, ... }:
let
  cascade = import ../den/_cascades/terminal-cascade.nix;
in
{
  den.aspects.alacritty-quake = {
    includes = map (name: den.aspects.${name}) (
      cascade.alacritty-quake.includes
      ++ [
        "alacritty"
        "zellij"
        "atuin"
        "blesh"
      ]
    );
    homeManager = {
      imports = [ ../../home/terminal.nix ];
      terminal.provider = "alacritty";
    };
  };
}
