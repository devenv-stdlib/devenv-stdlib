{ lib, ... }:
let
  project = import ../../../modules/lib/project.nix { inherit lib; };
in
{
  name = "go-ide";
  description = "Go VS Code / Cursor extension pack and format-on-save defaults.";
  when = cfg: (cfg.languages.go or { }).enable or false;
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
