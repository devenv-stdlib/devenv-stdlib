# First-class linters catalog (treefmt vs prek backends).
{
  lib,
  ...
}:
let
  stdlib = import ../../../stdlib { inherit lib; };
  inherit (stdlib) linters;
in
{
  testLintersCatalogBackends = {
    expr = {
      nixfmt = linters.catalog.nixfmt.backend;
      commitlint = linters.catalog.commitlint.backend;
      gitleaks = linters.catalog.gitleaks.backend;
      lycheeDefault = linters.catalog.lychee.defaultEnable;
    };
    expected = {
      nixfmt = "treefmt";
      commitlint = "prek";
      gitleaks = "prek";
      lycheeDefault = false;
    };
  };

  testTrimTrailingWhitespaceExcludesDevenvLock = {
    expr = linters.catalog.trim-trailing-whitespace.excludes;
    expected = [ "^devenv\\.lock$" ];
  };

  testEndOfFileFixerExcludesDevenvLock = {
    expr = linters.catalog.end-of-file-fixer.excludes;
    expected = [ "^devenv\\.lock$" ];
  };

  testHygieneHookWiringPassesCatalogExcludes = {
    expr =
      let
        text = builtins.readFile ../../../modules/hooks/common.nix;
      in
      {
        trim = lib.hasInfix "trim-trailing-whitespace.excludes" text;
        eof = lib.hasInfix "end-of-file-fixer.excludes" text;
      };
    expected = {
      trim = true;
      eof = true;
    };
  };

  testLintersAlwaysOnSplit = {
    expr = {
      treefmtHasNixfmt = lib.elem "nixfmt" linters.alwaysOnTreefmt;
      prekHasCommitlint = lib.elem "commitlint" linters.alwaysOnPrek;
      lycheeNotAlwaysOn = !(lib.elem "lychee" linters.alwaysOn);
      gitHooksHasTreefmt = lib.elem "treefmt" linters.alwaysOnGitHooks;
      gitHooksOmitsNixfmt = !(lib.elem "nixfmt" linters.alwaysOnGitHooks);
    };
    expected = {
      treefmtHasNixfmt = true;
      prekHasCommitlint = true;
      lycheeNotAlwaysOn = true;
      gitHooksHasTreefmt = true;
      gitHooksOmitsNixfmt = true;
    };
  };

  testReportEnabledTreefmtPrograms = {
    expr = stdlib.report.enabledTreefmtPrograms {
      nixfmt.enable = true;
      rustfmt.enable = false;
      ruff-check.enable = true;
    };
    expected = [
      "nixfmt"
      "ruff-check"
    ];
  };

  # treefmt-nix still exposes programs.ruff as a renamed alias of ruff-check.
  # Scanning it would builtins.trace an obsolete-option warning on every eval.
  testReportEnabledTreefmtProgramsSkipsRuffAlias = {
    expr = stdlib.report.enabledTreefmtPrograms {
      ruff.enable = true;
      ruff-check.enable = true;
      ruff-format.enable = false;
    };
    expected = [ "ruff-check" ];
  };
}
