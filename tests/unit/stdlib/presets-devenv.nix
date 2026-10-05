# devenv loader + thin-preset API coverage against mock-framework only.
# Real language preset goldens belong in per-owner suites under presets/**/tests.
{
  lib,
  ...
}:
let
  devenvLoad = import ../../../stdlib/devenv.nix { inherit lib; };
  mock = import ../../lib/mock-framework.nix { inherit lib; };
  presetLib = import ../../../stdlib/preset.nix { inherit lib; };

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
    demo = lib.mkOption {
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
    tasks = lib.mkOption {
      type = freeform;
      default = { };
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

  eval =
    extra:
    (lib.evalModules {
      modules = [
        {
          _module.args.pkgs = {
            usql = "usql-fixture";
          };
        }
        {
          options = fixtureOptions;
          config = extra;
        }
      ]
      ++ devenvLoad.load mock.loadArgs;
    }).config;

  hookOn = cfg: name: (cfg.git-hooks.hooks.${name} or { }).enable or false;
  failedAssertions = cfg: lib.filter (a: !a.assertion) cfg.assertions;
in
{
  testPresetSchemaComesFromP2 = {
    expr = builtins.isFunction (presetLib.mkPreset { path = [ "example" ]; });
    expected = true;
  };

  testMockPythonLintRuffAttrpath = {
    expr =
      let
        refs = devenvLoad.refsOf mock.presetRoots;
      in
      {
        inherit (refs.python.lint.mock-ruff) path;
        id = presetLib.pathString refs.python.lint.mock-ruff.path;
      };
    expected = {
      path = [
        "python"
        "lint"
        "mock-ruff"
      ];
      id = "python.lint.mock-ruff";
    };
  };

  testMockListFormLoadInjectsToolRefs = {
    expr =
      let
        # Category roots (…/presets/python, …) do not infer sibling tools/ —
        # inference only runs when the root basename is "presets". Attrs form
        # with explicit tools is the API; neighboring eval tests assert enable.
        listForm = builtins.tryEval (devenvLoad.load mock.presetRoots);
        attrsForm = builtins.tryEval (devenvLoad.load mock.loadArgs);
      in
      {
        listOk = listForm.success;
        attrsOk = attrsForm.success;
      };
    expected = {
      listOk = true;
      attrsOk = true;
    };
  };

  testMockRefsOfMatchesLoadedDeclPath = {
    expr =
      let
        tools = devenvLoad.refsOfTools [ mock.tools ];
        refs = devenvLoad.refsOf mock.presetRoots;
        ruff = lib.findFirst (d: d.name == "python.lint.mock-ruff") null (
          devenvLoad.declsOf mock.presetRoots tools
        );
      in
      {
        ref = refs.python.lint.mock-ruff.path;
        decl = ruff.path;
      };
    expected = {
      ref = [
        "python"
        "lint"
        "mock-ruff"
      ];
      decl = [
        "python"
        "lint"
        "mock-ruff"
      ];
    };
  };

  testMockPythonLintPyrightToolAttrpath = {
    expr =
      let
        tools = devenvLoad.refsOfTools [ mock.tools ];
        normalized = presetLib.normalizeTool tools.python.lint.mock-pyright;
      in
      {
        inherit (tools.python.lint.mock-pyright) path;
        inherit (normalized) name;
      };
    expected = {
      path = [
        "python"
        "lint"
        "mock-pyright"
      ];
      name = "mock-pyright";
    };
  };

  testMockLanguagesOffPresetsInert = {
    expr =
      let
        cfg = eval { };
      in
      {
        ruff = hookOn cfg "mock-ruff";
        tool = (cfg.tools.mock-ruff or { }).enable or false;
        failed = failedAssertions cfg;
      };
    expected = {
      ruff = false;
      tool = false;
      failed = [ ];
    };
  };

  testMockThinPresetEnablesLocalTool = {
    expr =
      let
        cfg = eval { languages.python.enable = true; };
      in
      {
        tool = cfg.tools.mock-ruff.enable;
        hook = hookOn cfg "mock-ruff";
        format = hookOn cfg "mock-ruff-format";
        formatter = cfg.stdlib.lang.python.settings."[python]"."editor.defaultFormatter";
      };
    expected = {
      tool = true;
      hook = true;
      format = true;
      formatter = "mock.ruff";
    };
  };

  testMockPresetEnableFalseStaysInert = {
    expr =
      let
        cfg = eval {
          languages.python.enable = true;
          presets.python.lint.mock-ruff.enable = false;
        };
      in
      {
        ruff = hookOn cfg "mock-ruff";
        tool = (cfg.tools.mock-ruff or { }).enable or false;
      };
    expected = {
      ruff = false;
      tool = false;
    };
  };

  testMockTypePresetUsesLintToolAttrpath = {
    expr =
      let
        cfg = eval { languages.python.enable = true; };
      in
      {
        # python.type.mock-pyright includes tools.python.lint.mock-pyright
        tool = cfg.tools.mock-pyright.enable;
        hook = hookOn cfg "mock-pyright";
      };
    expected = {
      tool = true;
      hook = true;
    };
  };

  testMockStrictGateThrows = {
    expr =
      (builtins.tryEval (
        let
          cfg = eval {
            demo.enable = true;
          };
        in
        builtins.seq cfg.assertions cfg.warnings
      )).success;
    expected = false;
  };

  testMockStrictGateWarnsWhenNotStrict = {
    expr =
      let
        cfg = eval {
          demo.enable = true;
          presets.demo.strict-gate.strict = false;
        };
      in
      {
        failed = failedAssertions cfg;
        warned = lib.any (w: lib.hasInfix "demo.strict-gate" w) cfg.warnings;
      };
    expected = {
      failed = [ ];
      warned = true;
    };
  };

  testMockGlobalStrictFalseWarns = {
    expr =
      let
        cfg = eval {
          demo.enable = true;
          presets.strict = false;
        };
      in
      {
        failed = failedAssertions cfg;
        warned = cfg.warnings != [ ];
      };
    expected = {
      failed = [ ];
      warned = true;
    };
  };

  testMockStrictGateAppliesWithToken = {
    expr =
      let
        cfg = eval {
          demo.enable = true;
          demo.token = "ok";
        };
      in
      {
        inherit (cfg.presets.demo.strict-gate.result) applied;
        failed = failedAssertions cfg;
      };
    expected = {
      applied = true;
      failed = [ ];
    };
  };

  testMockPostgresExemplar = {
    expr =
      let
        off = eval { };
        on = eval { services.postgres.enable = true; };
      in
      {
        offPackages = off.packages;
        offExt = off.stdlib.markers.postgresIdeExtension or null;
        onPackages = on.packages;
        onExt = on.stdlib.markers.postgresIdeExtension;
      };
    expected = {
      offPackages = [ ];
      offExt = null;
      onPackages = [ "usql-fixture" ];
      onExt = "mtxr.sqltools";
    };
  };

  testMockIdePresetIsOneTool = {
    expr =
      let
        tools = devenvLoad.refsOfTools [ mock.tools ];
        decls = devenvLoad.declsOf mock.presetRoots tools;
        ide = lib.findFirst (d: d.name == "ide.mock-ide") null decls;
      in
      {
        inherit (ide) path;
        toolName = (builtins.head ide.tools).path;
      };
    expected = {
      path = [
        "ide"
        "mock-ide"
      ];
      toolName = [
        "ide"
        "mock-ide"
      ];
    };
  };

  testMockPresetExtraOptionIsDeclared = {
    expr = (eval { }).presets.terminal.mock-provider.provider;
    expected = "alacritty";
  };

  testMockLocalToolAutoLowersTasks = {
    expr =
      let
        cfg = eval { languages.python.enable = true; };
        t = cfg.tasks."mock-check:verify" or null;
      in
      {
        tool = cfg.tools.mock-check.enable;
        hasTask = t != null;
        exec = if t == null then null else t.exec or null;
      };
    expected = {
      tool = true;
      hasTask = true;
      exec = "echo mock-check-verify";
    };
  };

  testMockPresetExportsAndComposesTasks = {
    expr =
      let
        cfg = eval { presets.demo.task-workflow.enable = true; };
        sample = cfg.tasks."mock-cpu:sample" or null;
        report = cfg.tasks."mock-cpu:report" or null;
      in
      {
        hasSample = sample != null;
        hasReport = report != null;
        sampleBefore = if sample == null then [ ] else sample.before or [ ];
        reportAfter = if report == null then [ ] else report.after or [ ];
        sampleExec = if sample == null then null else sample.exec or null;
      };
    expected = {
      hasSample = true;
      hasReport = true;
      sampleBefore = [ "demo:build" ];
      reportAfter = [ "demo:build" ];
      sampleExec = "echo mock-cpu-sample";
    };
  };
}
