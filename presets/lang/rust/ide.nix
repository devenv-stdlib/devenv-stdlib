{ lib, ... }:
let
  project = import ../../../modules/lib/project.nix { inherit lib; };
in
{
  name = "rust-ide";
  description = "Rust VS Code / Cursor extension pack and format-on-save defaults.";
  when = cfg: (cfg.languages.rust or { }).enable or false;
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
