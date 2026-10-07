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
            tasks = lib.mkOption {
              type = freeform;
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
        hasUpdateTask = cfg.tasks ? "ci:update-language-matrix";
        hasExtensionsTask = cfg.tasks ? "ides:update-extensions-json";
        hasSettingsTask = cfg.tasks ? "ides:update-settings-json";
        hasCompositeTask = cfg.tasks ? "stdlib:update-generated";
        enterWritesMatrix = contains "sync-language-versions-workflow" cfg.enterShell;
        enterHasStaleHint = contains "ci:update-language-matrix" cfg.enterShell;
        enterHasExtensionsHint = contains "ides:update-extensions-json" cfg.enterShell;
        filesHasExtensions = cfg.files ? ".vscode/extensions.json";
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
      hasUpdateTask = true;
      hasExtensionsTask = true;
      hasSettingsTask = true;
      hasCompositeTask = true;
      enterWritesMatrix = false;
      enterHasStaleHint = true;
      enterHasExtensionsHint = true;
      filesHasExtensions = false;
      reportWarning = true;
      enterHasReport = true;
      reportListsHooks = true;
      treefmtIncludesRuff = true;
    };
  };

  # listOf concatenates. The same multi-runtime lists in two modules
  # (nodejs+bun+deno, cpython+pypy) must not double those matrix rows.
  testCiLanguageMatrixDuplicateMultiRuntimesCollapse = {
    expr =
      let
        shared = {
          languages.javascript.enable = true;
          languages.python.enable = true;
          supported.javascript.runtimes = [
            "nodejs"
            "bun"
            "deno"
          ];
          supported.javascript.nodejs.min = "22";
          supported.javascript.nodejs.max = "22";
          supported.javascript.bun.min = "1";
          supported.javascript.bun.max = "1";
          supported.javascript.deno.min = "2.9";
          supported.javascript.deno.max = "2.9";
          supported.python.min = "3.12";
          supported.python.max = "3.12";
          supported.python.implementations = [
            "cpython"
            "pypy"
          ];
        };
        once = eval shared;
        twice = eval (
          lib.mkMerge [
            shared
            shared
          ]
        );
        rows = cfg: lang: cfg.stdlib.markers.ciMatrix.languages.${lang}.rows;
        yml =
          cfg:
          (lib.findFirst (g: g.path == ".github/workflows/test.yml") {
            source.text = "";
          } cfg.stdlib.generated).source.text;
      in
      {
        jsListedTwice =
          twice.supported.javascript.runtimes == [
            "nodejs"
            "bun"
            "deno"
            "nodejs"
            "bun"
            "deno"
          ];
        pyListedTwice =
          twice.supported.python.implementations == [
            "cpython"
            "pypy"
            "cpython"
            "pypy"
          ];
        jsRows = rows once "javascript" == rows twice "javascript";
        pyRows = rows once "python" == rows twice "python";
        workflow = yml once == yml twice;
      };
    expected = {
      jsListedTwice = true;
      pyListedTwice = true;
      jsRows = true;
      pyRows = true;
      workflow = true;
    };
  };

}
