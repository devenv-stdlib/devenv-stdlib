# Additive. Existing hook/serena/vscode tests keep using modules/lib/project.nix.
{
  lib,
  project,
  ...
}:
let
  devenvLoad = import ../../stdlib/devenv.nix { inherit lib; };
  presetRoot = ../../presets;

  freeform = lib.types.submodule {
    freeformType = lib.types.lazyAttrsOf lib.types.anything;
  };

  fixtureOptions = {
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
    processes = lib.mkOption {
      type = freeform;
      default = { };
    };
    services.postgres.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
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
  };

  eval =
    extra:
    (lib.evalModules {
      modules = [
        {
          _module.args.pkgs = {
            ty = "ty-fixture";
            usql = "usql-fixture";
          };
        }
        {
          options = fixtureOptions;
          config = extra;
        }
      ]
      ++ devenvLoad.load [
        (presetRoot + "/lang")
        (presetRoot + "/fixtures")
      ];
    }).config;

  hookOn = cfg: name: (cfg.git-hooks.hooks.${name} or { }).enable or false;

  failedAssertions = cfg: lib.filter (a: !a.assertion) cfg.assertions;

  vscodeFile = cfg: cfg.files.".vscode/extensions.json".json;

  serenaServers = cfg: cfg.files.".serena/project.yml".yaml.language_servers;
in
{
  # P2 owns stdlib/preset.nix. mkPreset is a Den module, not the old stub attrset.
  testPresetSchemaComesFromP2 = {
    expr = builtins.isFunction (
      (import ../../stdlib/preset.nix { inherit lib; }).mkPreset { name = "example"; }
    );
    expected = true;
  };

  testLanguagesOffMatchHelpers = {
    expr =
      let
        cfg = eval { };
      in
      {
        serena = serenaServers cfg;
        inherit ((vscodeFile cfg)) recommendations;
        unwanted = (vscodeFile cfg).unwantedRecommendations;
        debtmap = devenvLoad.debtmapLanguages cfg.stdlib.lang;
        ruff = hookOn cfg "ruff";
        prettier = hookOn cfg "prettier";
        rustfmt = hookOn cfg "rustfmt";
        gofmt = hookOn cfg "gofmt";
        processes = cfg.stdlib.markers.processes or false;
        postgres = cfg.stdlib.markers.postgresIdeExtension or null;
        failed = failedAssertions cfg;
      };
    expected = {
      serena = project.serenaLanguageServers { };
      recommendations = project.vscodeRecommendations { };
      unwanted = project.vscodeUnwanted { };
      debtmap = project.debtmapLanguages { };
      ruff = false;
      prettier = false;
      rustfmt = false;
      gofmt = false;
      processes = false;
      postgres = null;
      failed = [ ];
    };
  };

  testPythonPresetMatchesHelpers = {
    expr =
      let
        languages = {
          python.enable = true;
        };
        cfg = eval { inherit languages; };
      in
      {
        serena = serenaServers cfg;
        inherit ((vscodeFile cfg)) recommendations;
        unwanted = (vscodeFile cfg).unwantedRecommendations;
        debtmap = devenvLoad.debtmapLanguages cfg.stdlib.lang;
        got = {
          ruff = hookOn cfg "ruff";
          ruff-format = hookOn cfg "ruff-format";
          check-python = hookOn cfg "check-python";
          python-debug-statements = hookOn cfg "python-debug-statements";
          sort-requirements-txt = hookOn cfg "sort-requirements-txt";
          pyright = hookOn cfg "pyright";
          ty = hookOn cfg "ty";
          ci = cfg.stdlib.lang.python.ciMatrix;
          formatter = cfg.stdlib.markers.ideSettings."[python]"."editor.defaultFormatter";
        };
      };
    expected =
      let
        languages = {
          python.enable = true;
        };
        hooks = project.languageHooks { inherit languages; };
      in
      {
        serena = project.serenaLanguageServers languages;
        recommendations = project.vscodeRecommendations languages;
        unwanted = project.vscodeUnwanted languages;
        debtmap = project.debtmapLanguages languages;
        got = {
          inherit (hooks)
            ruff
            ruff-format
            check-python
            python-debug-statements
            sort-requirements-txt
            pyright
            ty
            ;
          ci = true;
          formatter = "charliermarsh.ruff";
        };
      };
  };

  testPythonTyHook = {
    expr =
      let
        cfg = eval {
          languages.python.enable = true;
          pythonTypeChecker = "ty";
        };
      in
      {
        pyright = hookOn cfg "pyright";
        ty = hookOn cfg "ty";
      };
    expected = {
      pyright = false;
      ty = true;
    };
  };

  testRustGoPresets = {
    expr =
      let
        languages = {
          rust.enable = true;
          go.enable = true;
        };
        cfg = eval {
          inherit languages;
          supported.rust.edition = "2024";
        };
      in
      {
        serena = serenaServers cfg;
        debtmap = devenvLoad.debtmapLanguages cfg.stdlib.lang;
        rustfmt = hookOn cfg "rustfmt";
        clippy = hookOn cfg "clippy";
        args = cfg.git-hooks.hooks.rustfmt.args;
        gofmt = hookOn cfg "gofmt";
        golangci = hookOn cfg "golangci-lint";
        editionArg = cfg.stdlib.markers.ideSettings."rust-analyzer.rustfmt.extraArgs";
      };
    expected = {
      serena = project.serenaLanguageServers {
        rust.enable = true;
        go.enable = true;
      };
      debtmap = project.debtmapLanguages {
        rust.enable = true;
        go.enable = true;
      };
      rustfmt = true;
      clippy = true;
      args = [
        "--edition"
        "2024"
      ];
      gofmt = true;
      golangci = true;
      editionArg = [
        "--edition"
        "2024"
      ];
    };
  };

  testJavascriptAndTypescriptSharePack = {
    expr =
      let
        js = eval {
          languages.javascript.enable = true;
        };
        ts = eval {
          languages.typescript.enable = true;
          typescript.bundler = "vite";
        };
        both = eval {
          languages.javascript.enable = true;
          languages.typescript.enable = true;
          typescript.bundler = "vite";
        };
      in
      {
        jsSerena = serenaServers js;
        tsSerena = serenaServers ts;
        bothSerena = serenaServers both;
        jsDebt = devenvLoad.debtmapLanguages js.stdlib.lang;
        tsDebt = devenvLoad.debtmapLanguages ts.stdlib.lang;
        bothDebt = devenvLoad.debtmapLanguages both.stdlib.lang;
        jsPrettier = hookOn js "prettier";
        tsPrettier = hookOn ts "prettier";
        bothPrettier = hookOn both "prettier";
        jsRecs = (vscodeFile js).recommendations;
        tsRecs = (vscodeFile ts).recommendations;
        ci = {
          js = js.stdlib.lang.javascript.ciMatrix or false;
          tsFromJs = js.stdlib.lang.typescript.ciMatrix or false;
          ts = ts.stdlib.lang.typescript.ciMatrix or false;
          jsFromTs = ts.stdlib.lang.javascript.ciMatrix or false;
        };
      };
    expected = {
      jsSerena = project.serenaLanguageServers { javascript.enable = true; };
      tsSerena = project.serenaLanguageServers { typescript.enable = true; };
      bothSerena = project.serenaLanguageServers {
        javascript.enable = true;
        typescript.enable = true;
      };
      jsDebt = project.debtmapLanguages { javascript.enable = true; };
      tsDebt = project.debtmapLanguages { typescript.enable = true; };
      bothDebt = project.debtmapLanguages {
        javascript.enable = true;
        typescript.enable = true;
      };
      jsPrettier = true;
      tsPrettier = true;
      bothPrettier = true;
      jsRecs = project.vscodeRecommendations { javascript.enable = true; };
      tsRecs = project.vscodeRecommendations { typescript.enable = true; };
      ci = {
        js = true;
        tsFromJs = false;
        ts = true;
        jsFromTs = false;
      };
    };
  };

  # P2 realize throws when strict requirements fail, instead of leaving a failed assertion.
  testTypescriptBundlerRequiresStrict = {
    expr =
      (builtins.tryEval (
        let
          cfg = eval {
            languages.typescript.enable = true;
          };
        in
        builtins.seq cfg.assertions cfg.warnings
      )).success;
    expected = false;
  };

  testTypescriptBundlerWarnsWhenNotStrict = {
    expr =
      let
        cfg = eval {
          languages.typescript.enable = true;
          presets.typescript-bundler.strict = false;
        };
      in
      {
        failed = failedAssertions cfg;
        warnings = map (w: lib.hasInfix "typescript.bundler" w) cfg.warnings;
        # Tool presets stay independent: bundler failure does not disable prettier/debtmap.
        prettier = hookOn cfg "prettier";
        debtmap = devenvLoad.debtmapLanguages cfg.stdlib.lang;
      };
    expected = {
      failed = [ ];
      warnings = [ true ];
      prettier = true;
      debtmap = [ "typescript" ];
    };
  };

  testPresetEnableFalseStaysInert = {
    expr =
      let
        cfg = eval {
          languages.python.enable = true;
          presets.ruff.enable = false;
          presets.serena-python.enable = false;
        };
      in
      {
        ruff = hookOn cfg "ruff";
        serena = serenaServers cfg;
      };
    expected = {
      ruff = false;
      serena = project.serenaLanguageServers { };
    };
  };

  testGlobalStrictFalseWarns = {
    expr =
      let
        cfg = eval {
          languages.typescript.enable = true;
          presets.strict = false;
        };
      in
      {
        failed = failedAssertions cfg;
        warned = cfg.warnings != [ ];
        # prettier is a separate tool preset; global strict only affects requires.
        prettier = hookOn cfg "prettier";
      };
    expected = {
      failed = [ ];
      warned = true;
      prettier = true;
    };
  };

  testProcessesExemplar = {
    expr =
      let
        off = eval { };
        on = eval {
          processes.web.exec = "true";
        };
      in
      {
        off = off.stdlib.markers.processes or false;
        on = on.stdlib.markers.processes or false;
      };
    expected = {
      off = false;
      on = true;
    };
  };

  testPostgresExemplar = {
    expr =
      let
        off = eval { };
        on = eval {
          services.postgres.enable = true;
        };
      in
      {
        offPackages = off.packages;
        offExt = off.stdlib.markers.postgresIdeExtension or null;
        onPackages = on.packages;
        onExt = on.stdlib.markers.postgresIdeExtension;
        onRec = lib.elem "mtxr.sqltools" (vscodeFile on).recommendations;
        inherit
          (import ../../presets/fixtures/postgres.nix {
            inherit lib;
            stdlib = import ../../stdlib/preset.nix { inherit lib; };
          })
          tools
          ;
      };
    expected = {
      offPackages = [ ];
      offExt = null;
      onPackages = [ "usql-fixture" ];
      onExt = "mtxr.sqltools";
      onRec = true;
      tools = [ "usql" ];
    };
  };

  testEnterShellSyncsCursor = {
    expr = lib.hasInfix "cursor-sync-extensions" (eval { }).enterShell;
    expected = true;
  };
}
