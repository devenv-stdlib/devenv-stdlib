# JS/TS share prettier, the Serena typescript server, and the TS IDE pack.
# Not a preset (underscore: loader skips it).
{ lib }:
let
  project = import ../../modules/lib/project.nix { inherit lib; };
in
{
  gitHooks.prettier = {
    enable = true;
    files = "\\.(cjs|js|jsx|mjs|ts|tsx)$";
  };
  contrib = {
    serena = [ "typescript" ];
    vscodeIds = project.vscodeLanguageIds.typescript;
    extensionSet = "typescript";
    settings = {
      "eslint.validate" = [
        "javascript"
        "javascriptreact"
        "typescript"
        "typescriptreact"
      ];
      "[typescript]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.formatOnSave" = true;
      };
      "[typescriptreact]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.formatOnSave" = true;
      };
      "[javascript]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.formatOnSave" = true;
      };
      "[javascriptreact]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.formatOnSave" = true;
      };
    };
  };
}
