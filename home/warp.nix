{
  pkgs,
  lib,
  config,
  ...
}:
let
  warpLib = import ./warp-lib.nix { inherit lib; };
  cfg = config.warp;
  warp-terminal = warpLib.mkPackage pkgs;
  warpExe = lib.getExe warp-terminal;
in
{
  options.warp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Warp, Starship, Quake settings, and the GNOME shortcut.";
    };

    quakeKeybinding = lib.mkOption {
      type = lib.types.str;
      default = "f12";
      description = ''
        Quake-mode shortcut in Warp settings.toml form (modifiers and a key
        joined by `-`, for example f12, ctrl-`, or alt-enter).
        Override from home.local.nix:

          { warp.quakeKeybinding = "ctrl-`"; }
      '';
    };

    extraSettings = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra TOML appended to `~/.config/warp-terminal/settings.toml`.
        Use this for appearance and other keys; the file is Home Manager-owned.
      '';
    };

    gnomeExtraCustomKeybindings = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra GNOME `custom-keybindings` paths to keep next to Warp Quake.
        Home Manager replaces that array, so list any other shortcuts here.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    home = {
      packages = [ warp-terminal ];
      sessionVariables.WARP_ENABLE_WAYLAND = "1";
    };

    # Do not enable programs.bash: that replaces ~/.bashrc. Starship init stays
    # in the existing bashrc as `eval "$(starship init bash)"`.
    programs.starship = {
      enable = true;
      enableBashIntegration = false;
    };

    xdg.configFile."warp-terminal/settings.toml" = {
      text = warpLib.settingsToml cfg.quakeKeybinding cfg.extraSettings;
      force = true;
    };

    xdg.desktopEntries."dev.warp.Warp" = {
      name = "Warp";
      genericName = "Terminal Emulator";
      comment = "Warp terminal with Wayland and Quake mode";
      exec = "env WARP_ENABLE_WAYLAND=1 ${warpExe} %U";
      icon = "warp-terminal";
      terminal = false;
      categories = [
        "System"
        "TerminalEmulator"
      ];
      settings = {
        StartupWMClass = "dev.warp.Warp";
        Keywords = "shell;prompt;command;commandline;cmd;";
      };
    };

    dconf.settings = {
      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          warpLib.gnomeShortcutPath
        ]
        ++ cfg.gnomeExtraCustomKeybindings;
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${warpLib.gnomeShortcutId}" = {
        name = "Warp Quake";
        command = warpExe;
        binding = warpLib.toGnomeBinding cfg.quakeKeybinding;
      };
    };
  };
}
