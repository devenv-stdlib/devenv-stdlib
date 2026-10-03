{ lib, stdlib }:
let
  project = import ../../modules/lib/project.nix { inherit lib; };
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  versionPolicy = import ./_version-policy.nix { inherit lib; };
in
stdlib.mkPreset {
  name = "python";
  description = "Python hooks, Ruff IDE pack, Serena, debtmap, and CI matrix inputs.";
  when = cfg: (cfg.languages.python or { }).enable or false;
  module = _: {
    options.supported.python = lib.mkOption {
      type = lib.types.submodule {
        options = versionPolicy {
          implementations = lib.mkOption {
            type = lib.types.listOf (lib.types.enum versions.pythonImpls);
            default = [ "cpython" ];
            description = "Python 3 implementations to test. cpython and/or pypy.";
          };
        };
      };
      default = { };
    };
  };
  project =
    { config, pkgs, ... }:
    let
      checker = config.pythonTypeChecker or "pyright";
    in
    {
      git-hooks.hooks = {
        ruff.enable = true;
        ruff-format.enable = true;
        check-python.enable = true;
        python-debug-statements.enable = true;
        sort-requirements-txt.enable = true;
        pyright.enable = checker == "pyright";
        ty = {
          enable = checker == "ty";
          name = "ty";
          description = "Astral ty type checker (beta)";
          package = pkgs.ty;
          entry = "${pkgs.ty}/bin/ty check";
          files = "\\.py$";
        };
      };

      stdlib.lang.python = {
        serena = [ "python" ];
        debtmap = [ "python" ];
        vscodeIds = project.vscodeLanguageIds.python;
        extensionSet = "python";
        ciMatrix = true;
        settings = {
          "python.languageServer" = "Pylance";
          "[python]" = {
            "editor.defaultFormatter" = "charliermarsh.ruff";
            "editor.formatOnSave" = true;
            "editor.codeActionsOnSave" = {
              "source.fixAll.ruff" = "explicit";
              "source.organizeImports.ruff" = "explicit";
            };
          };
        };
      };
    };
}
