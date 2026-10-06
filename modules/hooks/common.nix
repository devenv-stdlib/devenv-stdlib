# Residual git-hooks / prek checks — secret scanning, commit-msg, hygiene,
# and other tools that are a poor fit for treefmt. Formatters and file
# linters that treefmt-nix supports live under options.linters.* and lower
# into devenv's treefmt integration (modules/linters + git-hooks.hooks.treefmt).
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.linters;
  lintersLib = import ../../stdlib/linters.nix { inherit lib; };
in
{
  # Vendored upstream skills (Vercel skills CLI); not ours to lint or reflow.
  git-hooks.excludes = [ "^\\.agents/skills/" ];

  git-hooks.hooks = {
    commitlint = lib.mkIf cfg.commitlint.enable {
      enable = true;
      name = "commitlint";
      description = "Lint commit messages as Conventional Commits";
      package = pkgs.commitlint;
      entry = "${pkgs.commitlint}/bin/commitlint --edit";
      stages = [ "commit-msg" ];
    };

    proselint = lib.mkIf cfg.proselint.enable {
      enable = true;
      files = "\\.(md|rst|txt)$";
      # git-hooks.nix still calls `proselint FILE`; 0.16 needs `check`.
      entry = "${pkgs.proselint}/bin/proselint check";
    };

    lychee =
      let
        # lychee does not retry reqwest connect failures ("Connection failed" on
        # nixos.org/donate/ in CI). Retry the whole check without excluding hosts.
        flags = "--cache --max-cache-age 2d --exclude '^https://devenv4monorepo\\.github\\.io'";
        lycheeRetry = pkgs.writeShellScriptBin "lychee-ci-retry" ''
          set -eu
          max=4
          n=1
          while true; do
            if ${lib.getExe pkgs.lychee} ${flags} "$@"; then
              exit 0
            fi
            rc=$?
            if [ "$n" -ge "$max" ]; then
              exit "$rc"
            fi
            sleep $((n * 8))
            n=$((n + 1))
          done
        '';
      in
      lib.mkIf cfg.lychee.enable {
        # Off by default (linters.lychee.enable). Keep this retry wrapper and lychee.toml.
        enable = true;
        files = "\\.(md|html)$";
        package = pkgs.lychee;
        entry = lib.getExe lycheeRetry;
      };

    check-json = lib.mkIf cfg.check-json.enable {
      enable = true;
    };

    check-toml = lib.mkIf cfg.check-toml.enable {
      enable = true;
    };

    taplo-lint = lib.mkIf cfg."taplo-lint".enable {
      enable = true;
      name = "taplo-lint";
      description = "Lint TOML files with taplo";
      package = pkgs.taplo;
      entry = "${pkgs.taplo}/bin/taplo lint";
      types = [ "toml" ];
    };

    trim-trailing-whitespace = lib.mkIf cfg.trim-trailing-whitespace.enable {
      enable = true;
      excludes = lintersLib.catalog.trim-trailing-whitespace.excludes;
    };

    end-of-file-fixer = lib.mkIf cfg.end-of-file-fixer.enable {
      enable = true;
    };

    check-added-large-files = lib.mkIf cfg.check-added-large-files.enable {
      enable = true;
    };

    check-case-conflicts = lib.mkIf cfg.check-case-conflicts.enable {
      enable = true;
    };

    check-merge-conflicts = lib.mkIf cfg.check-merge-conflicts.enable {
      enable = true;
      args = [ "--assume-in-merge" ];
    };

    gitleaks = lib.mkIf cfg.gitleaks.enable {
      enable = true;
      name = "gitleaks";
      description = "Detect hardcoded secrets";
      package = pkgs.gitleaks;
      entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged --redact";
      pass_filenames = false;
    };
  };
}
