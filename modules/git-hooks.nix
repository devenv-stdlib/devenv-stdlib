{
  pkgs,
  lib,
  config,
  ...
}:
let
  project = import ./project-lib.nix { inherit lib; };
  hooks = project.languageHooks {
    languages = config.languages or { };
    inherit (config) pythonTypeChecker;
  };
in
{
  git-hooks.hooks = {
    nixfmt-rfc-style.enable = true;
    statix.enable = true;
    deadnix.enable = true;
    shellcheck.enable = true;
    commitlint = {
      enable = true;
      name = "commitlint";
      description = "Lint commit messages as Conventional Commits";
      package = pkgs.commitlint;
      entry = "${pkgs.commitlint}/bin/commitlint --edit";
      stages = [ "commit-msg" ];
    };

    typos.enable = true;
    proselint = {
      enable = true;
      files = "\\.(md|rst|txt)$";
      # git-hooks.nix still calls `proselint FILE`; 0.16 needs `check`.
      entry = "${pkgs.proselint}/bin/proselint check";
    };
    lychee = {
      enable = true;
      files = "\\.(md|html)$";
      settings.flags = "--cache --max-cache-age 2d";
    };
    actionlint.enable = true;
    yamlfmt = {
      enable = true;
      excludes = [ "^\\.pre-commit-config\\.yaml$" ];
      settings = {
        lint-only = false;
        configPath = ".yamlfmt";
      };
    };
    gitleaks = {
      enable = true;
      name = "gitleaks";
      description = "Detect hardcoded secrets";
      package = pkgs.gitleaks;
      entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged --redact";
      pass_filenames = false;
    };

    rustfmt.enable = hooks.rustfmt;
    clippy.enable = hooks.clippy;

    gofmt.enable = hooks.gofmt;
    golangci-lint.enable = hooks.golangci-lint;

    ruff.enable = hooks.ruff;
    ruff-format.enable = hooks.ruff-format;
    pyright.enable = hooks.pyright;
    ty = {
      enable = hooks.ty;
      name = "ty";
      description = "Astral ty type checker (beta)";
      package = pkgs.ty;
      entry = "${pkgs.ty}/bin/ty check";
      files = "\\.py$";
    };

    prettier = {
      enable = hooks.prettier;
      files = "\\.(cjs|js|jsx|mjs|ts|tsx)$";
    };
  };
}
