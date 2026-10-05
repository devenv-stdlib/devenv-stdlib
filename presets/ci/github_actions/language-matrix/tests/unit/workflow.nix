# Real CI matrix preset: owns workflow sync + report surface (not mocked).
{ lib, ... }:
let
  devenvLoad = import <devenv4monorepo/stdlib/devenv.nix> { inherit lib; };
  presetRoot = <devenv4monorepo/presets>;
  toolsRoot = <devenv4monorepo/tools>;

  freeform = lib.types.submodule {
    freeformType = lib.types.lazyAttrsOf lib.types.anything;
  };

  eval =
    extra:
    (lib.evalModules {
      modules = [
        {
          _module.args.pkgs = {
            writeText = name: text: {
              inherit name text;
              outPath = "/tmp/${name}";
            };
          };
        }
        {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              default = "fixture";
            };
            languages = lib.mkOption {
              type = freeform;
              default = { };
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
            };
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
            };
            warnings = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            enterShell = lib.mkOption {
              type = lib.types.lines;
              default = "";
            };
            git-hooks.hooks = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
            };
            # Real language formatters (rustfmt/gofmt/prettier/ruff) set
            # treefmt.config; stub the option so owner-suite evals that load
            # tools/ without devenv's treefmt module still type-check.
            treefmt = lib.mkOption {
              type = freeform;
              default = { };
            };
            files = lib.mkOption {
              type = lib.types.attrsOf freeform;
              default = { };
            };
            scripts = lib.mkOption {
              type = lib.types.attrsOf freeform;
              default = { };
            };
          };
          config = extra;
        }
      ]
      ++ devenvLoad.load {
        presets = devenvLoad.defaultRoots presetRoot;
        tools = [ toolsRoot ];
      };
    }).config;

  contains = needle: haystack: lib.hasInfix needle haystack;
in
{
  testCiLanguageMatrixPresetOwnsWorkflow = {
    expr =
      let
        cfg = eval {
          languages.python.enable = true;
          supported.python.min = "3.12";
        };
      in
      {
        applied = cfg.presets.ci.github_actions.language-matrix.result.applied or false;
        attrpath = contains "ci.github_actions.language-matrix" (
          lib.concatStringsSep "\n" (map (w: w) cfg.warnings)
        );
        hasMarker = cfg.stdlib.markers ? ciMatrix;
        matrixEmpty = (cfg.stdlib.markers.ciMatrix or { }).empty or true;
        hasSync = cfg.scripts ? sync-language-versions-workflow;
        reportWarning = lib.any (w: lib.hasInfix "stdlib status:" w) cfg.warnings;
        enterHasReport = contains "stdlib status:" cfg.enterShell;
        reportListsHooks = lib.any (w: lib.hasInfix "ruff" w) cfg.warnings;
        # Ruff lives on treefmt (ruff-check / ruff-format), not git-hooks.ruff.
        treefmtIncludesRuff =
          ((cfg.treefmt.config.programs.ruff-check or { }).enable or false)
          && ((cfg.treefmt.config.programs.ruff-format or { }).enable or false);
      };
    expected = {
      applied = true;
      attrpath = true;
      hasMarker = true;
      matrixEmpty = false;
      hasSync = true;
      reportWarning = true;
      enterHasReport = true;
      reportListsHooks = true;
      treefmtIncludesRuff = true;
    };
  };

}
