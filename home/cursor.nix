{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.cursor;
  mesaDrivers = pkgs.mesa;
  glLibs = lib.makeLibraryPath [
    pkgs.libglvnd
    mesaDrivers
    pkgs.libdrm
    pkgs.wayland
    pkgs.libxkbcommon
  ];

  # chrome-sandbox cannot be root 4755 in the Nix store, so --no-sandbox is
  # always required off NixOS. Mesa + X11 are only for VMware (SVGA / no
  # /run/opengl-driver); systemd-detect-virt decides at launch.
  cursorPkg = pkgs.writeShellApplication {
    name = "cursor";
    text = ''
      extra=()
      virt=""
      if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt="$(systemd-detect-virt 2>/dev/null || true)"
      elif [ -x /usr/bin/systemd-detect-virt ]; then
        virt="$(/usr/bin/systemd-detect-virt 2>/dev/null || true)"
      fi
      if [ "$virt" = vmware ]; then
        export LD_LIBRARY_PATH="${glLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export LIBGL_DRIVERS_PATH="${mesaDrivers}/lib/dri''${LIBGL_DRIVERS_PATH:+:$LIBGL_DRIVERS_PATH}"
        export __EGL_VENDOR_LIBRARY_DIRS="${mesaDrivers}/share/glvnd/egl_vendor.d''${__EGL_VENDOR_LIBRARY_DIRS:+:$__EGL_VENDOR_LIBRARY_DIRS}"
        extra+=(--ozone-platform=x11)
      fi
      exec ${lib.getExe pkgs.code-cursor} --no-sandbox "''${extra[@]}" "$@"
    '';
  };
in
{
  imports = [ ./cursor-extensions.nix ];

  options.cursor.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Install Cursor from nixpkgs plus common editor extensions.
      Language packs are installed by devenv when languages.* is enabled.
      programs.cursor is not used: it replaces ~/.config/Cursor/User/settings.json.
    '';
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    home.packages = [ cursorPkg ];

    # gnome-shell often starts without ~/.nix-profile/share on XDG_DATA_DIRS.
    xdg.dataFile."applications/cursor.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Cursor
      Comment=AI-powered code editor
      Exec=${lib.getExe cursorPkg} %F
      Icon=${pkgs.code-cursor}/share/pixmaps/cursor.png
      Terminal=false
      Categories=Development;IDE;
      StartupWMClass=Cursor
      MimeType=text/plain;inode/directory;
    '';
  };
}
