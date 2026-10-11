# VS Code from nixpkgs. Off unless vscode.enable (Cursor is the default IDE).
args@{
  pkgs,
  lib,
  config,
  ...
}:
# pkgs and config stay in the signature so Den does not call this without pkgs.
# The false branch is never evaluated; it only marks those names as used.
if false then
  { inherit pkgs config; }
else
  let
    tool = import ../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "vscode";
      category = "ide";
      install = {
        kind = "nix";
        attr = "vscode";
      };
      upgrade = "flake";
      # The module is imported with the home; vscode.enable is the real switch.
      defaultEnable = true;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.apply args (
      spec
      // {
        imports = [ ../../home/ides/vscode-extensions.nix ];

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

        homeManager =
          {
            pkgs,
            lib,
            config,
            ...
          }:
          lib.mkIf config.vscode.enable {
            nixpkgs.config.allowUnfree = true;
            home.packages = [ pkgs.vscode ];
          };
      }
    )
