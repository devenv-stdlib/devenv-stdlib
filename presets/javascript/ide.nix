# Shared JS/TS editor pack (one extension set for both languages).
{ lib, ... }:
let
  project = import ../../modules/lib/project.nix { inherit lib; };
in
{
  path = [
    "javascript"
    "ide"
  ];
  description = "TypeScript/JavaScript VS Code / Cursor extension pack.";
  when =
    cfg:
    ((cfg.languages.javascript or { }).enable or false)
    || ((cfg.languages.typescript or { }).enable or false);
  project.stdlib.lang.javascript = {
    vscodeIds = project.vscodeLanguageIds.typescript;
    extensionSet = "typescript";
    settings = {
      "eslint.validate" = [
        "javascript"
        "javascriptreact"
        "typescript"
        "typescriptreact"
      ];
    };
  };
}
