{ pkgs, config, ... }:
let
  langOn = name: (config.languages.${name} or { }).enable or false;
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
  };
}
