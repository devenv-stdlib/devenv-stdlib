{
  pkgs,
  lib,
  config,
  ...
}:
let
  # FHS wrapper sees the host Mesa/VMware driver; the plain Nix package
  # hits the same "display handle is not supported" wall as Nix Alacritty.
  cursorPkg = pkgs.code-cursor-fhs or pkgs.code-cursor;

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
      Install Cursor, the devenv VS Code extension, and Nix IDE. programs.cursor
      is not used: it replaces ~/.config/Cursor/User/settings.json.
    '';
  };

  config = lib.mkIf config.cursor.enable {
    nixpkgs.config.allowUnfree = true;

    home.packages = [ cursorPkg ];

    # Both the Nix Cursor and the existing AppImage read ~/.cursor/extensions.
    home.file = {
      ".cursor/extensions/datakurre.devenv".source = extensionRoot devenvExtension;
      ".cursor/extensions/jnoortheen.nix-ide".source = extensionRoot nixIdeExtension;
    };
  };
}
