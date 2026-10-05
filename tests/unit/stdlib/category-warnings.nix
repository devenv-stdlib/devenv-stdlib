# Unused-category warnings for available language/service categories.
{ lib, ... }:
let
  stdlib = import ../../../stdlib { inherit lib; };
  inherit (stdlib) categoryWarnings;

  warnFor =
    {
      config ? { },
      tools ? [ ],
      leaves ? [ ],
    }:
    categoryWarnings.unusedWarnings {
      inherit config tools leaves;
      presets = { };
    };

  hasWarn = path: warnings: lib.any (w: lib.hasInfix "category ${path}:" w) warnings;
in
{
  testCategoryWarningsApiExport = {
    expr = {
      hasUnused = stdlib ? categoryWarnings && stdlib.categoryWarnings ? unusedWarnings;
      nChecks = builtins.length categoryWarnings.checks;
    };
    expected = {
      hasUnused = true;
      # 58 langs × 2 (lang + linters) + 43 services
      nChecks = 159;
    };
  };

  testCategoryWarningsSilentWhenUnavailable = {
    expr = warnFor { } == [ ];
    expected = true;
  };

  testCategoryWarningsWhenLanguageAvailableUnused = {
    expr =
      let
        ws = warnFor {
          config = {
            languages.zig.enable = true;
          };
        };
      in
      {
        hasZig = hasWarn "lang.zig" ws;
        hasZigLinters = hasWarn "lang.zig.linters" ws;
        noPython = !(hasWarn "lang.python" ws);
      };
    expected = {
      hasZig = true;
      hasZigLinters = true;
      noPython = true;
    };
  };

  testCategoryWarningsClearedByAppliedPreset = {
    expr =
      let
        ws = warnFor {
          config = {
            languages.python.enable = true;
          };
          leaves = [
            {
              path = [
                "python"
                "lint"
                "ruff"
              ];
              result = {
                applied = true;
                triggered = true;
                inert = false;
              };
            }
          ];
        };
      in
      {
        noPython = !(hasWarn "lang.python" ws);
        noLinters = !(hasWarn "lang.python.linters" ws);
      };
    expected = {
      noPython = true;
      noLinters = true;
    };
  };

  testCategoryWarningsLintersOnlyWhenParentHasNonLintPreset = {
    expr =
      let
        ws = warnFor {
          config = {
            languages.python.enable = true;
          };
          leaves = [
            {
              path = [
                "python"
                "ide"
              ];
              result = {
                applied = true;
                triggered = true;
                inert = false;
              };
            }
          ];
        };
      in
      {
        noPython = !(hasWarn "lang.python" ws);
        hasLinters = hasWarn "lang.python.linters" ws;
      };
    expected = {
      noPython = true;
      hasLinters = true;
    };
  };

  testCategoryWarningsClearedByEnabledTool = {
    expr =
      let
        ws = warnFor {
          config = {
            languages.python.enable = true;
          };
          tools = [
            {
              name = "ruff";
              category = "lang.python.linters";
              enable = true;
            }
          ];
        };
      in
      {
        # Tool under linters also covers the lang.python prefix.
        noPython = !(hasWarn "lang.python" ws);
        noLinters = !(hasWarn "lang.python.linters" ws);
      };
    expected = {
      noPython = true;
      noLinters = true;
    };
  };

  # Docs site (and other TS-only consumers) enable languages.typescript and get
  # Prettier via javascript.lint.prettier (javascript-or-typescript). That must
  # clear lang.typescript.linters — not only lang.javascript.linters.
  testCategoryWarningsSharedJsTsLintClearsTypescriptLinters = {
    expr =
      let
        ws = warnFor {
          config = {
            languages.typescript.enable = true;
          };
          leaves = [
            {
              path = [
                "javascript"
                "lint"
                "prettier"
              ];
              result = {
                applied = true;
                triggered = true;
                inert = false;
              };
            }
            {
              path = [
                "typescript"
                "bundler"
              ];
              result = {
                applied = true;
                triggered = true;
                inert = false;
              };
            }
          ];
        };
      in
      {
        noTypescript = !(hasWarn "lang.typescript" ws);
        noTypescriptLinters = !(hasWarn "lang.typescript.linters" ws);
        # javascript itself is not available → no javascript warnings either.
        noJavascript = !(hasWarn "lang.javascript" ws);
        noJavascriptLinters = !(hasWarn "lang.javascript.linters" ws);
      };
    expected = {
      noTypescript = true;
      noTypescriptLinters = true;
      noJavascript = true;
      noJavascriptLinters = true;
    };
  };

  testCategoryWarningsSharedJsTsToolClearsTypescriptLinters = {
    expr =
      let
        ws = warnFor {
          config = {
            languages.typescript.enable = true;
          };
          tools = [
            {
              name = "prettier";
              category = "lang.javascript.linters";
              enable = true;
            }
          ];
          leaves = [
            {
              path = [
                "typescript"
                "debtmap"
              ];
              result = {
                applied = true;
                triggered = true;
                inert = false;
              };
            }
          ];
        };
      in
      {
        noTypescriptLinters = !(hasWarn "lang.typescript.linters" ws);
      };
    expected = {
      noTypescriptLinters = true;
    };
  };

  testCategoryWarningsServiceUnused = {
    expr =
      let
        ws = warnFor {
          config = {
            services.postgres.enable = true;
          };
        };
      in
      {
        hasPostgres = hasWarn "services.postgres" ws;
        noRedis = !(hasWarn "services.redis" ws);
      };
    expected = {
      hasPostgres = true;
      noRedis = true;
    };
  };

  testCategoryWarningsOptOutModule = {
    expr =
      let
        freeform = lib.types.submodule {
          freeformType = lib.types.lazyAttrsOf lib.types.anything;
        };
        eval =
          extra:
          (lib.evalModules {
            modules = [
              categoryWarnings.optionsModule
              categoryWarnings.module
              {
                options = {
                  languages = lib.mkOption {
                    type = freeform;
                    default = { };
                  };
                  services = lib.mkOption {
                    type = freeform;
                    default = { };
                  };
                  presets = lib.mkOption {
                    type = freeform;
                    default = { };
                  };
                  warnings = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                  };
                };
                config = extra;
              }
            ];
          }).config;
        on = eval {
          languages.zig.enable = true;
        };
        off = eval {
          languages.zig.enable = true;
          stdlib.categoryWarnings.enable = false;
        };
      in
      {
        onHas = hasWarn "lang.zig" on.warnings;
        offEmpty = off.warnings == [ ];
      };
    expected = {
      onHas = true;
      offEmpty = true;
    };
  };
}
