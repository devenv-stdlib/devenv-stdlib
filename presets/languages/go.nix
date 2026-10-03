{ lib, stdlib }:
let
  project = import ../../modules/lib/project.nix { inherit lib; };
  versionPolicy = import ./_version-policy.nix { inherit lib; };
in
stdlib.mkPreset {
  name = "go";
  description = "Go hooks, IDE pack, Serena, debtmap, and CI matrix inputs.";
  when = cfg: (cfg.languages.go or { }).enable or false;
  module = _: {
    options.supported.go = lib.mkOption {
      type = lib.types.submodule { options = versionPolicy { }; };
      default = { };
    };
  };
  project = {
    git-hooks.hooks = {
      gofmt.enable = true;
      golangci-lint.enable = true;
    };

    stdlib.lang.go = {
      serena = [ "go" ];
      debtmap = [ "go" ];
      vscodeIds = project.vscodeLanguageIds.go;
      extensionSet = "go";
      ciMatrix = true;
      settings = {
        "go.useLanguageServer" = true;
        "[go]" = {
          "editor.defaultFormatter" = "golang.go";
          "editor.formatOnSave" = true;
        };
      };
    };
  };
}
