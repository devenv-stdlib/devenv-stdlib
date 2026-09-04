{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.cursor;
  mesaDrivers = pkgs.mesa.drivers or pkgs.mesa;

  # code-cursor-fhs uses bubblewrap; Ubuntu 24.04 blocks unprivileged uid
  # maps. chrome-sandbox cannot be root 4755 in the Nix store, so
  # --no-sandbox is required off NixOS. Mesa + X11 cover VMware GL.
  cursorPkg = pkgs.symlinkJoin {
    name = "cursor";
    paths = [ pkgs.code-cursor ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/cursor \
        --prefix LD_LIBRARY_PATH : "${
          lib.makeLibraryPath [
            pkgs.libglvnd
            mesaDrivers
            pkgs.libdrm
            pkgs.wayland
            pkgs.libxkbcommon
          ]
        }" \
        --prefix LIBGL_DRIVERS_PATH : "${mesaDrivers}/lib/dri" \
        --prefix __EGL_VENDOR_LIBRARY_DIRS : "${mesaDrivers}/share/glvnd/egl_vendor.d" \
        --add-flags "--ozone-platform=x11 --no-sandbox"
    '';
  };

  devenvExtension = pkgs.vscode-utils.extensionFromVscodeMarketplace {
    name = "devenv";
    publisher = "datakurre";
    version = "0.7.0";
    sha256 = "1bjmjrg13zynala76vz5vpm4ann1dic6awiv03w2l9rkby4agba7";
  };

  nixIdeExtension = pkgs.vscode-extensions.jnoortheen.nix-ide;

  extensionRoot = ext: "${ext}/share/vscode/extensions/${ext.vscodeExtUniqueId}";
in
{
  options.cursor.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Install Cursor from nixpkgs, plus the devenv and Nix IDE extensions.
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

    home.file = {
      ".cursor/extensions/datakurre.devenv".source = extensionRoot devenvExtension;
      ".cursor/extensions/jnoortheen.nix-ide".source = extensionRoot nixIdeExtension;
    };
  };
}
