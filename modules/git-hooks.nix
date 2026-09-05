{ pkgs, config, ... }:
let
  langOn = name: (config.languages.${name} or { }).enable or false;
  pythonOn = langOn "python";
  typescriptOn = langOn "javascript" || langOn "typescript";
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

    rustfmt.enable = langOn "rust";
    clippy.enable = langOn "rust";

    gofmt.enable = langOn "go";
    golangci-lint.enable = langOn "go";

    ruff.enable = pythonOn;
    ruff-format.enable = pythonOn;
    pyright.enable = pythonOn && config.pythonTypeChecker == "pyright";
    ty = {
      enable = pythonOn && config.pythonTypeChecker == "ty";
      name = "ty";
      description = "Astral ty type checker (beta)";
      package = pkgs.ty;
      entry = "${pkgs.ty}/bin/ty check";
      files = "\\.py$";
    };

    prettier = {
      enable = typescriptOn;
      files = "\\.(cjs|js|jsx|mjs|ts|tsx)$";
    };
  };
}
