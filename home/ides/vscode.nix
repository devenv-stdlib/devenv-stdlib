{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.vscode;
in
{
  imports = [ ./vscode-extensions.nix ];

  options.vscode.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Install VS Code from nixpkgs plus common editor extensions under
      ~/.vscode/extensions. Off by default; Cursor is the default GUI IDE.
      Language packs are installed by devenv when languages.* is enabled
      (vscode-sync-extensions). programs.vscode is not used: it replaces
      user settings.json.
    '';
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    home.packages = [ pkgs.vscode ];
  };
}
