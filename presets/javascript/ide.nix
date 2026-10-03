# Shared JS/TS editor pack. Uses javascript-or-typescript category policy.
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
  categoryPolicy = "javascript-or-typescript";
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
