# Editor pack / language-server settings not owned by a single CLI tool.
{ lib, ... }:
let
  project = import ../../../modules/lib/project.nix { inherit lib; };
in
{
  name = "python-ide";
  description = "Python VS Code / Cursor extension pack and Pylance setting.";
  when = cfg: (cfg.languages.python or { }).enable or false;
  project.stdlib.lang.python = {
    vscodeIds = project.vscodeLanguageIds.python;
    extensionSet = "python";
    settings."python.languageServer" = "Pylance";
  };
}
