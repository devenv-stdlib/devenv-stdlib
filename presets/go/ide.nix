# when inherits go category policy (languages.go.enable or override).
{ lib, ... }:
let
  project = import ../../modules/lib/project.nix { inherit lib; };
in
{
  path = [
    "go"
    "ide"
  ];
  description = "Go VS Code / Cursor extension pack and format-on-save defaults.";
  project.stdlib.lang.go = {
    vscodeIds = project.vscodeLanguageIds.go;
    extensionSet = "go";
    settings = {
      "go.useLanguageServer" = true;
      "[go]" = {
        "editor.defaultFormatter" = "golang.go";
        "editor.formatOnSave" = true;
      };
    };
  };
}
