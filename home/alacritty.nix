{
  pkgs,
  lib,
  config,
  ...
}:
let
  terminalLib = import ./terminal-lib.nix { inherit lib; };
  cfg = config.terminal;

  extension = pkgs.gnomeExtensions.quake-terminal;
  desktopId = terminalLib.desktopIds.alacritty;
  quakeDesktopId = terminalLib.desktopIds.alacrittyQuake;
  # The extension shell-parses Exec and spawns it itself, without startup
  # notification, so GNOME can only tie the window back to this desktop file
  # through the Wayland app_id. --class sets it; it must match the file name.
  appId = lib.removeSuffix ".desktop" desktopId;
  quakeAppId = lib.removeSuffix ".desktop" quakeDesktopId;
  icon = "${pkgs.alacritty}/share/icons/hicolor/scalable/apps/Alacritty.svg";
  alacrittyExe = lib.getExe alacrittyPkg;
  zellijExe = lib.getExe pkgs.zellij;

  # Nix Alacritty cannot see Ubuntu/VMware Mesa. Point it at Nix's EGL
  # and DRI drivers instead of mixing host libc into LD_LIBRARY_PATH.
  mesaDrivers = pkgs.mesa.drivers or pkgs.mesa;
  alacrittyPkg = pkgs.symlinkJoin {
    name = "alacritty";
    paths = [ pkgs.alacritty ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/alacritty \
        --prefix LD_LIBRARY_PATH : "${
          lib.makeLibraryPath [
            pkgs.libglvnd
            mesaDrivers
            pkgs.libdrm
          ]
        }" \
        --prefix LIBGL_DRIVERS_PATH : "${mesaDrivers}/lib/dri" \
        --prefix __EGL_VENDOR_LIBRARY_DIRS : "${mesaDrivers}/share/glvnd/egl_vendor.d"
    '';
  };
in
{
  options.alacritty.zellijSession = lib.mkOption {
    type = lib.types.str;
    default = "quake";
    description = ''
      Zellij session the F12 dropdown attaches to, creating it on first use.
      Closing the dropdown keeps the panes and scrollback.
    '';
  };

  options.alacritty.zellijGuiSession = lib.mkOption {
    type = lib.types.str;
    default = "main";
    description = ''
      Zellij session for Alacritty launched from the dash or app grid. Kept
      separate from the dropdown so a sidebar window is a normal frame.
    '';
  };

  config = lib.mkIf (cfg.provider == "alacritty") {
    programs = {
      alacritty = {
        enable = true;
        package = alacrittyPkg;
        settings = {
          # Decorations stay on for dash/app-grid launches. The dropdown
          # overrides this with -o window.decorations=None on its own Exec.
          window.padding = {
            x = 8;
            y = 8;
          };
          scrolling.history = 50000;
          font.size = 11.0;
        };
      };

      zellij = {
        enable = true;
        # Shell integration stays off: it would start Zellij in every shell,
        # including the devenv one. The desktop entry below starts it instead.
        settings = {
          default_layout = "compact";
          copy_command = "wl-copy";
          show_startup_tips = false;
        };
      };

      atuin = {
        enable = true;
        enableBashIntegration = true;
        # User systemd + socket activation (generic Linux). Do not set
        # settings.daemon.autostart: it is incompatible with systemd_socket.
        daemon.enable = true;
        forceOverwriteSettings = true;
        settings.search_mode = "daemon-fuzzy";
      };
    };

    home.packages = [
      pkgs.wl-clipboard
      extension
    ];

    home.file.".local/share/gnome-shell/extensions/${terminalLib.quakeExtensionUuid}" = {
      # gnome-shell scans this directory and the system ones, never the Nix
      # profile, so the extension is linked in rather than left on PATH.
      source = "${extension}/share/gnome-shell/extensions/${terminalLib.quakeExtensionUuid}";
    };

    xdg.dataFile = {
      "applications/${desktopId}".text = terminalLib.mkDesktopEntry {
        name = "Alacritty (Zellij)";
        comment = "Alacritty running Zellij";
        exec = "${alacrittyExe} --class ${appId} -e ${zellijExe} attach --create ${config.alacritty.zellijGuiSession}";
        inherit icon;
        wmClass = appId;
      };
      # Hidden from the app grid; the Quake extension launches this by id.
      "applications/${quakeDesktopId}".text = terminalLib.mkDesktopEntry {
        name = "Alacritty (Quake)";
        comment = "Dropdown Alacritty, launched only by the Quake Terminal extension";
        exec = "${alacrittyExe} --class ${quakeAppId} -o window.decorations=None -e ${zellijExe} attach --create ${config.alacritty.zellijSession}";
        inherit icon;
        wmClass = quakeAppId;
        noDisplay = true;
      };
    };

    dconf.settings."org/gnome/shell/extensions/quake-terminal" = {
      terminal-id = quakeDesktopId;
      terminal-shortcut = [ (terminalLib.toGnomeBinding cfg.quakeKeybinding) ];
      vertical-size = cfg.heightPercent;
      horizontal-size = 100;
      auto-hide-window = true;
      always-on-top = true;
      hide-from-overview = true;
      render-on-current-monitor = true;
    };
  };
}
