# stdlib.log / report inventory / mock CI matrix preset (mock-framework only).
{
  lib,
  versions,
  ...
}:
let
  stdlib = import ../../../stdlib { inherit lib; };
  devenvLoad = import ../../../stdlib/devenv.nix { inherit lib; };
  mock = import ../../lib/mock-framework.nix { inherit lib; };

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
            demo = lib.mkOption {
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
            files = lib.mkOption {
              type = lib.types.attrsOf freeform;
              default = { };
            };
            scripts = lib.mkOption {
              type = lib.types.attrsOf freeform;
              default = { };
            };
            tasks = lib.mkOption {
              type = freeform;
              default = { };
            };
          };
          config = extra;
        }
      ]
      ++ devenvLoad.load mock.loadArgs;
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
        inherit (inv.presets) applied inert;
        tools = inv.tools.enabled;
        hooks = inv.gitHooks.enabled;
        matrixEmpty = inv.matrix.empty;
        hasRuffPath = contains "python.lint.ruff" text;
        hasMatrix = contains "Build matrix" text;
        hasPython = contains "python:" text;
        hasNaviHint = contains stdlib.report.toolsNaviHint text;
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
      hasNaviHint = true;
    };
  };

  testReportInventoryWalksNamespacedToolTrees = {
    expr =
      let
        inv = stdlib.report.inventory {
          tools = {
            python = {
              lint = {
                ruff = {
                  enable = true;
                };
                pyright = {
                  enable = false;
                };
              };
            };
            javascript = {
              lint = {
                prettier = {
                  enable = true;
                };
              };
            };
            alacritty = {
              enable = true;
            };
            warp = {
              enable = false;
            };
          };
        };
        text = stdlib.report.formatReport inv;
      in
      {
        tools = inv.tools.enabled;
        hasNamespaced = contains "python.lint.ruff" text;
        notNone = !(contains "Enabled tools: (none)" text);
      };
    expected = {
      tools = [
        "alacritty"
        "javascript.lint.prettier"
        "python.lint.ruff"
      ];
      hasNamespaced = true;
      notNone = true;
    };
  };

  testReportGeneratedFilesDryRunOnEnterShell = {
    expr =
      let
        inv = stdlib.report.inventory {
          generated = [
            {
              path = ".github/workflows/test.yml";
              task = "ci:update-language-matrix";
              script = "sync-language-versions-workflow";
              source = "/nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-test.yml";
            }
            {
              path = ".vscode/extensions.json";
              task = "ides:update-extensions-json";
              script = "sync-vscode-extensions-json";
              source = "/nix/store/ffffffffffffffffffffffffffffffff-extensions.json";
            }
          ];
        };
        text = stdlib.report.formatReport inv;
        enter = stdlib.report.mkEnterShellSnippet inv;
      in
      {
        paths = map (g: g.path) inv.generated;
        formatListsMatrix = contains ".github/workflows/test.yml ← ci:update-language-matrix" text;
        formatListsExtensions = contains ".vscode/extensions.json ← ides:update-extensions-json" text;
        formatListsComposite = contains "stdlib:update-generated" text;
        enterHasCmp = contains "cmp -s" enter;
        enterHasStaleHint = contains "is stale — run: devenv tasks run ci:update-language-matrix" enter;
        enterHasComposite = contains "devenv tasks run stdlib:update-generated" enter;
        enterHasUpToDate = contains "Generated files: up to date" enter;
      };
    expected = {
      paths = [
        ".github/workflows/test.yml"
        ".vscode/extensions.json"
      ];
      formatListsMatrix = true;
      formatListsExtensions = true;
      formatListsComposite = true;
      enterHasCmp = true;
      enterHasStaleHint = true;
      enterHasComposite = true;
      enterHasUpToDate = true;
    };
  };

  testReportEnsureNewlineDryRunDoesNotCmpSource = {
    expr =
      let
        inv = stdlib.report.inventory {
          generated = [
            {
              path = "example.lock";
              task = "example:ensure-newline";
              script = "sync-example-lock";
              mode = "ensure-newline";
            }
          ];
        };
        enter = stdlib.report.mkEnterShellSnippet inv;
      in
      {
        inherit ((builtins.head inv.generated)) mode;
        usesTail = contains "tail -c1" enter;
        namesFile = contains "example.lock is stale" enter;
        noCmpAgainstEmptySource = !(contains "cmp -s ''" enter);
      };
    expected = {
      mode = "ensure-newline";
      usesTail = true;
      namesFile = true;
      noCmpAgainstEmptySource = true;
    };
  };

  testMockCiLanguageMatrixPresetOwnsWorkflow = {
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
        hasUpdateTask = cfg.tasks ? "ci:update-language-matrix";
        hasCompositeTask = cfg.tasks ? "stdlib:update-generated";
        enterWritesMatrix = contains "sync-language-versions-workflow" cfg.enterShell;
        enterHasStaleHint = contains "ci:update-language-matrix" cfg.enterShell;
        reportWarning = lib.any (w: lib.hasInfix "stdlib status:" w) cfg.warnings;
        enterHasReport = contains "stdlib status:" cfg.enterShell;
        hooksIncludeRuff = (cfg.git-hooks.hooks.mock-ruff or { }).enable or false;
        reportListsHooks = lib.any (w: lib.hasInfix "mock-ruff" w) cfg.warnings;
        reportListsGenerated = lib.any (w: lib.hasInfix ".github/workflows/test.yml" w) cfg.warnings;
      };
    expected = {
      applied = true;
      attrpath = true;
      hasMarker = true;
      matrixEmpty = false;
      hasSync = true;
      hasUpdateTask = true;
      hasCompositeTask = true;
      enterWritesMatrix = false;
      enterHasStaleHint = true;
      reportWarning = true;
      enterHasReport = true;
      hooksIncludeRuff = true;
      reportListsHooks = true;
      reportListsGenerated = true;
    };
  };

  testReportListsToolsEnabledByThinPresets = {
    expr =
      let
        cfg = eval {
          languages.python.enable = true;
          supported.python.min = "3.12";
        };
        report = lib.findFirst (w: lib.hasInfix "stdlib status:" w) "" cfg.warnings;
      in
      {
        ruffEnable = cfg.tools.mock-ruff.enable;
        pyrightEnable = cfg.tools.mock-pyright.enable;
        reportListsRuff = contains "  - mock-ruff" report;
        reportListsPyright = contains "  - mock-pyright" report;
        toolsNotNone = !(contains "Enabled tools: (none)" report);
      };
    expected = {
      ruffEnable = true;
      pyrightEnable = true;
      reportListsRuff = true;
      reportListsPyright = true;
      toolsNotNone = true;
    };
  };

  testReportHintsNaviForToolUsage = {
    expr =
      let
        withTools = stdlib.report.formatReport (
          stdlib.report.inventory {
            tools = {
              ruff = {
                enable = true;
              };
            };
          }
        );
        withoutTools = stdlib.report.formatReport (
          stdlib.report.inventory {
            tools = { };
          }
        );
        hint = stdlib.report.toolsNaviHint;
      in
      {
        inherit hint;
        withToolsHasHint = contains hint withTools;
        withoutToolsHasHint = contains hint withoutTools;
        exactWording = hint == "Use navi <tool name> to understand its usage.";
        afterEnabledTools =
          (contains "Enabled tools:\n  - ruff\n${hint}" withTools)
          && (contains "Enabled tools: (none)\n${hint}" withoutTools);
      };
    expected = {
      hint = "Use navi <tool name> to understand its usage.";
      withToolsHasHint = true;
      withoutToolsHasHint = true;
      exactWording = true;
      afterEnabledTools = true;
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

  testFlattenPresetLeavesIncludesHubChildren = {
    expr = map (l: l.id) (
      stdlib.report.flattenPresetLeaves {
        strict = false;
        hub = {
          enable = true;
          result.applied = true;
          child = {
            enable = false;
            result.applied = false;
          };
        };
      }
    );
    expected = [
      "hub"
      "hub.child"
    ];
  };
}
