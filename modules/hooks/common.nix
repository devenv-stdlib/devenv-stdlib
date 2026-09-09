{
  pkgs,
  ...
}:
{
  # Vendored upstream skills (Vercel skills CLI); not ours to lint or reflow.
  git-hooks.excludes = [ "^\\.agents/skills/" ];

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
  };
}
