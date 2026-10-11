# Quake dropdown: exactly one terminal provider (B1) plus GNOME wiring.
# Same file serves both loaders:
#   - stdlib.devenv.load passes `tools` → thin preset declaration
#   - Den / evalModules import without `tools` → mkPreset module
args@{ lib, ... }:
let
  inherit (import ../../stdlib/preset.nix { inherit lib; }) mkPreset;
  toolLib = import ../../stdlib/tool.nix { inherit lib; };
  loadLib = import ../../stdlib/load.nix { inherit lib; };
  tools = toolLib.refsFromSpecs (toolLib.specs (loadLib.discover [ ../../tools ]));

  spec = {
    path = [
      "terminal"
      "quake"
    ];
    description = "Exactly one quake terminal provider, plus the GNOME dropdown wiring.";

    extraOptions.provider = lib.mkOption {
      type = lib.types.enum [
        "alacritty"
        "warp"
      ];
      default = "alacritty";
      description = ''
        Which terminal is bound to the quake shortcut. The other tool on the
        terminal category node is excluded; nested mux tools are not.
      '';
    };

    tools = cfg: [
      tools.terminal.${cfg.presets.terminal.quake.provider}
    ];

    configure = cfg: {
      terminal.provider = cfg.presets.terminal.quake.provider;
    };

    homeManager.imports = [ ../../home/terminal.nix ];
  };
in
if args ? tools then
  spec
else
  {
    imports = [ (mkPreset spec) ];
  }
