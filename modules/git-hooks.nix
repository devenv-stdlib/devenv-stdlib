{
  pkgs,
  lib,
  config,
  ...
}:
let
  project = import ./project-lib.nix { inherit lib; };
  versions = import ./language-versions-lib.nix { inherit lib; };
  languages = config.languages or { };
  hooks = project.languageHooks {
    inherit languages;
    inherit (config) pythonTypeChecker;
  };
  debtmapPkg = import ./debtmap-pkg.nix { inherit pkgs lib; };
in
{
  git-hooks.hooks = {
    nixfmt.enable = true;
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
      settings.flags = "--cache --max-cache-age 2d --exclude '^https://devenv4monorepo\\.github\\.io'";
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
    check-json.enable = true;
    trim-trailing-whitespace.enable = true;
    end-of-file-fixer.enable = true;
    check-added-large-files.enable = true;
    check-case-conflicts.enable = true;
    check-merge-conflicts = {
      enable = true;
      args = [ "--assume-in-merge" ];
    };
    gitleaks = {
      enable = true;
      name = "gitleaks";
      description = "Detect hardcoded secrets";
      package = pkgs.gitleaks;
      entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged --redact";
      pass_filenames = false;
    };

    rustfmt = {
      enable = hooks.rustfmt;
      args = versions.rustfmtEditionArgs (config.supported.rust.edition or null);
    };
    clippy.enable = hooks.clippy;

    gofmt.enable = hooks.gofmt;
    golangci-lint.enable = hooks.golangci-lint;

    ruff.enable = hooks.ruff;
    ruff-format.enable = hooks.ruff-format;
    check-python.enable = hooks.check-python;
    python-debug-statements.enable = hooks.python-debug-statements;
    sort-requirements-txt.enable = hooks.sort-requirements-txt;
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

    debtmap = {
      enable = hooks.debtmap;
      name = "debtmap";
      description = "Analyze technical debt for enabled languages";
      package = debtmapPkg;
      entry = "${debtmapPkg}/bin/debtmap analyze . --no-tui --quiet";
      files = project.debtmapFiles languages;
      pass_filenames = false;
    };
  };
}
