# Additive: stdlib.log API, report inventory, ci.language-matrix preset.
{
  lib,
  versions,
  ...
}:
let
  stdlib = import ../../stdlib { inherit lib; };
  devenvLoad = import ../../stdlib/devenv.nix { inherit lib; };
  presetRoot = ../../presets;

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
            pythonTypeChecker = lib.mkOption {
              type = lib.types.str;
              default = "pyright";
            };
            typescript.bundler = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
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
            files = lib.mkOption {
              type = lib.types.attrsOf freeform;
              default = { };
            };
            scripts = lib.mkOption {
              type = lib.types.attrsOf freeform;
              default = { };
            };
            tools = lib.mkOption {
              type = lib.types.attrsOf freeform;
              default = { };
            };
          };
          config = extra;
        }
      ]
      ++ devenvLoad.load (devenvLoad.defaultRoots presetRoot);
    }).config;

  contains = needle: haystack: lib.hasInfix needle haystack;
in
{
  testStdlibLogApiSurface = {
    expr = {
      inherit (stdlib.log) usingNixLog;
      hasDebug = builtins.isFunction stdlib.log.debug;
      hasWarnIf = builtins.isFunction stdlib.log.warnIf;
      hasDebugPrime = builtins.isFunction stdlib.log.debug';
    };
    expected = {
      # Unit import has no flake input; private fallback is fine.
      usingNixLog = false;
      hasDebug = true;
      hasWarnIf = true;
      hasDebugPrime = true;
    };
  };

  testReportInventoryListsHooksAndPresets = {
    expr =
      let
        inv = stdlib.report.inventory {
          presets = {
            python = {
              lint = {
                ruff = {
                  enable = true;
                  result = {
                    applied = true;
                    triggered = true;
                    inert = false;
                  };
                };
              };
            };
            demo = {
              inert = {
                enable = true;
                result = {
                  applied = false;
                  triggered = true;
                  inert = true;
                };
              };
            };
          };
          tools = {
            alacritty = {
              enable = true;
            };
            warp = {
              enable = false;
            };
          };
          gitHooks = {
            ruff = {
              enable = true;
            };
            lychee = {
              enable = false;
            };
            nixfmt = {
              enable = true;
            };
          };
          matrix = versions.matrixReport {
            pythonOn = true;
            python = versions.emptyPython // {
              min = "3.12";
            };
          };
        };
        text = stdlib.report.formatReport inv;
      in
      {
        applied = inv.presets.applied;
        inert = inv.presets.inert;
        tools = inv.tools.enabled;
        hooks = inv.gitHooks.enabled;
        matrixEmpty = inv.matrix.empty;
        hasRuffPath = contains "python.lint.ruff" text;
        hasMatrix = contains "Build matrix" text;
        hasPython = contains "python:" text;
      };
    expected = {
      applied = [ "python.lint.ruff" ];
      inert = [ "demo.inert" ];
      tools = [ "alacritty" ];
      hooks = [
        "nixfmt"
        "ruff"
      ];
      matrixEmpty = false;
      hasRuffPath = true;
      hasMatrix = true;
      hasPython = true;
    };
  };

  testCiLanguageMatrixPresetOwnsWorkflow = {
    expr =
      let
        cfg = eval {
          languages.python.enable = true;
          # Same requirement as real devenv.local.nix / versions.problems.
          supported.python.min = "3.12";
        };
      in
      {
        applied = cfg.presets.ci.language-matrix.result.applied or false;
        attrpath = contains "ci.language-matrix" (lib.concatStringsSep "\n" (map (w: w) cfg.warnings));
        hasMarker = cfg.stdlib.markers ? ciMatrix;
        matrixEmpty = (cfg.stdlib.markers.ciMatrix or { }).empty or true;
        hasSync = cfg.scripts ? sync-language-versions-workflow;
        reportWarning = lib.any (w: lib.hasInfix "stdlib status:" w) cfg.warnings;
        enterHasReport = contains "stdlib status:" cfg.enterShell;
        reportListsHooks = lib.any (w: lib.hasInfix "ruff" w) cfg.warnings;
        hooksIncludeRuff = (cfg.git-hooks.hooks.ruff or { }).enable or false;
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
      hooksIncludeRuff = true;
    };
  };

  testReportCanBeDisabled = {
    expr =
      let
        cfg = eval {
          stdlib.report.enable = false;
        };
      in
      {
        reportWarning = lib.any (w: lib.hasInfix "stdlib status:" w) cfg.warnings;
      };
    expected = {
      reportWarning = false;
    };
  };

  testMatrixReportEmpty = {
    expr = (versions.matrixReport { }).empty;
    expected = true;
  };
}
