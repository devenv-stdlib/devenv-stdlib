# CodeRabbit VS Code / Cursor extension from Open VSX (not Marketplace).
# Catalog pin: coderabbit-vscode. Linked under ~/.cursor or ~/.vscode when the
# matching IDE tool is on.
args@{
  pkgs,
  lib,
  config,
  ...
}:
if false then
  { inherit pkgs config; }
else
  let
    tool = import ../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "coderabbit";
      category = "ide";
      install = {
        kind = "vscode-extension";
        publisher = "coderabbit";
        extension = "coderabbit-vscode";
        registry = "open-vsx";
      };
      upgrade = "catalog";
      defaultEnable = true;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.apply args (
      spec
      // {
        homeManager =
          {
            pkgs,
            lib,
            config,
            ...
          }:
          let
            ext = import ../../stdlib/ide-ext.nix { inherit pkgs; };
            e = ext.coderabbit;
            link = dir: {
              home.file."${dir}/extensions/${ext.id e}".source = ext.root e;
            };
          in
          lib.mkMerge [
            (lib.mkIf (config.cursor.enable or false) (link ".cursor"))
            (lib.mkIf (config.vscode.enable or false) (link ".vscode"))
          ];
      }
    )
