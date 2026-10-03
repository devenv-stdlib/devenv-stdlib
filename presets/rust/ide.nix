# when inherits rust category policy (languages.rust.enable or override).
{ lib, ... }:
let
  project = import ../../modules/lib/project.nix { inherit lib; };
in
{
  path = [
    "rust"
    "ide"
  ];
  description = "Rust VS Code / Cursor extension pack and format-on-save defaults.";
  project.stdlib.lang.rust = {
    vscodeIds = project.vscodeLanguageIds.rust;
    extensionSet = "rust";
    settings = {
      "[rust]" = {
        "editor.defaultFormatter" = "rust-lang.rust-analyzer";
        "editor.formatOnSave" = true;
      };
    };
  };
}
