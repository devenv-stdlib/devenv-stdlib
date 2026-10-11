# First-class linter catalog — parallel to devenv languages.* modeling.
#
# Cross-cutting / always-on checks live under options.linters.<name>.enable
# (see modules/linters). Each entry declares a backend:
#   - treefmt: wired through devenv's treefmt integration (treefmt-nix)
#   - prek:    stays on git-hooks / prek (commit-msg, secrets, hygiene, …)
#
# Language-gated formatters (rustfmt, ruff, prettier, gofmt, …) remain mkTool
# leaves under tools/lang/*/linters and enable treefmt programs from their
# project payload when applied. They are not duplicated in this catalog.
{ lib }:
let
  mkTreefmt = program: defaultEnable: description: {
    backend = "treefmt";
    inherit
      program
      defaultEnable
      description
      ;
  };

  mkPrek =
    defaultEnable: description: extra:
    {
      backend = "prek";
      program = null;
      inherit defaultEnable description;
    }
    // extra;

  catalog = {
    # --- treefmt-backed (formatters / file linters) ---
    nixfmt = mkTreefmt "nixfmt" true "Format Nix with nixfmt (RFC style).";
    statix = mkTreefmt "statix" true "Lint Nix with statix.";
    deadnix = mkTreefmt "deadnix" true "Find unused Nix bindings with deadnix.";
    nixf-diagnose =
      mkTreefmt "nixf-diagnose" true
        "Diagnose Nix with nixf-diagnose (nixd's nixf-tidy).";
    shellcheck = mkTreefmt "shellcheck" true "Lint shell scripts with ShellCheck.";
    yamlfmt = mkTreefmt "yamlfmt" true "Format YAML with yamlfmt.";
    typos = mkTreefmt "typos" true "Spell-check source with typos.";
    actionlint = mkTreefmt "actionlint" true "Lint GitHub Actions workflows with actionlint.";
    taplo = mkTreefmt "taplo" true "Format TOML with taplo.";

    # --- prek / git-hooks only (poor fit for treefmt) ---
    commitlint = mkPrek true "Lint commit messages as Conventional Commits." {
      stages = [ "commit-msg" ];
    };
    gitleaks = mkPrek true "Detect hardcoded secrets in the staged diff." { };
    proselint = mkPrek true "Lint prose in Markdown / rst / txt." {
      files = "\\.(md|rst|txt)$";
    };
    lychee = mkPrek false "Check Markdown / HTML links (off by default)." {
      files = "\\.(md|html)$";
    };
    check-json = mkPrek true "Reject invalid JSON." { };
    check-toml = mkPrek true "Reject invalid TOML (syntax)." { };
    taplo-lint = mkPrek true "Lint TOML with taplo lint." { };
    trim-trailing-whitespace = mkPrek true "Strip trailing whitespace." {
      excludes = [ "^devenv\\.lock$" ];
    };
    end-of-file-fixer = mkPrek true "Ensure a trailing newline at EOF." {
      excludes = [ "^devenv\\.lock$" ];
    };
    check-added-large-files = mkPrek true "Block unexpectedly large added files." { };
    check-case-conflicts = mkPrek true "Detect filename case conflicts." { };
    check-merge-conflicts = mkPrek true "Detect merge conflict markers." { };
  };

  treefmt = lib.filterAttrs (_: v: v.backend == "treefmt") catalog;
  prek = lib.filterAttrs (_: v: v.backend == "prek") catalog;

  namesWhere =
    pred: lib.sort (a: b: a < b) (lib.filter (name: pred catalog.${name}) (builtins.attrNames catalog));

  alwaysOnTreefmt = namesWhere (v: v.backend == "treefmt" && v.defaultEnable);
  alwaysOnPrek = namesWhere (v: v.backend == "prek" && v.defaultEnable);

  # Logical always-on check names (treefmt programs + residual prek hooks).
  # git-hooks itself exposes a single `treefmt` hook plus the prek residual set.
  alwaysOn = alwaysOnTreefmt ++ alwaysOnPrek;
in
{
  inherit
    catalog
    treefmt
    prek
    alwaysOnTreefmt
    alwaysOnPrek
    alwaysOn
    ;

  # Names actually enabled on git-hooks when catalog defaults apply.
  alwaysOnGitHooks = [ "treefmt" ] ++ alwaysOnPrek;
}
