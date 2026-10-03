# ble.sh before Atuin/Starship, and Atuin's daemon search settings.
{ lib, ... }:
let
  inherit (import ../stdlib/preset.nix { inherit lib; }) mkPreset;
in
{
  imports = [
    (mkPreset {
      name = "alacritty-atuin";
      description = "ble.sh before Atuin and Starship, with Atuin's daemon fuzzy search.";

      extraOptions.tools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "atuin"
          "blesh"
        ];
        description = "Tools that must be enabled for this preset. Both atuin and blesh are required.";
      };

      tools = cfg: cfg.presets.alacritty-atuin.tools;

      requires = [
        {
          assertion = cfg: builtins.elem "atuin" cfg.presets.alacritty-atuin.tools;
          message = "alacritty-atuin requires the atuin tool to be enabled";
        }
        {
          assertion = cfg: builtins.elem "blesh" cfg.presets.alacritty-atuin.tools;
          message = "alacritty-atuin requires the blesh tool to be enabled";
        }
      ];

      homeManager =
        { pkgs, lib, ... }:
        {
          programs.atuin = {
            enable = true;
            enableBashIntegration = true;
            # User systemd + socket activation (generic Linux). Do not set
            # settings.daemon.autostart: it is incompatible with systemd_socket.
            daemon.enable = true;
            forceOverwriteSettings = true;
            settings.search_mode = "daemon-fuzzy";
          };

          # ble.sh before Atuin/Starship (those land in initExtra at default order).
          programs.bash.initExtra = lib.mkBefore ''
            source -- "${pkgs.blesh}/share/blesh/ble.sh"
          '';

          home.packages = [ pkgs.blesh ];

          xdg.configFile."blesh/init.sh".text = ''
            bleopt highlight_syntax=on
          '';
        };
    })
  ];
}
