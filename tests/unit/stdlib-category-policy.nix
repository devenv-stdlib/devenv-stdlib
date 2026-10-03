# Additive coverage for category-wide policies (python first instance).
{ lib, ... }:
let
  stdlib = import ../../stdlib { inherit lib; };
  categoryPolicy = stdlib.categoryPolicy;
  devenvLoad = import ../../stdlib/devenv.nix { inherit lib; };
  presetRoot = ../../presets;
  toolRoot = ../../tools;

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
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
    };
  };

  eval =
    extra:
    (lib.evalModules {
      modules = [
        {
          _module.args.pkgs = {
            ty = "ty-fixture";
          };
        }
        {
          options = fixtureOptions;
          config = extra;
        }
      ]
      ++ devenvLoad.load {
        presets = devenvLoad.defaultRoots presetRoot;
        tools = [ toolRoot ];
      };
    }).config;

  failedAssertions = cfg: map (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions);

  evalTool =
    extra:
    (lib.evalModules {
      modules = [
        categoryPolicy.optionsModule
        {
          options = fixtureOptions;
          config = extra;
        }
        (
          args@{
            pkgs ? { },
            lib,
            config,
            ...
          }:
          import ../../tools/lang/python/linters/ruff.nix {
            inherit pkgs lib config;
          }
        )
      ];
    }).config;
in
{
  testCategoryPolicyPythonRegistered = {
    expr = {
      ids = categoryPolicy.policyIds;
      preset = (categoryPolicy.forPresetPath [
        "python"
        "lint"
        "ruff"
      ]).id;
      tool = (categoryPolicy.forToolCategory "lang.python.linters").id;
      annotated = (stdlib.categories.resolve "lang.python").categoryPolicy;
    };
    expected = {
      ids = [ "python" ];
      preset = "python";
      tool = "python";
      annotated = "python";
    };
  };

  testCategoryPolicyAvailableViaLanguage = {
    expr = categoryPolicy.policies.python.available {
      languages.python.enable = true;
    };
    expected = true;
  };

  testCategoryPolicyAvailableViaOverride = {
    expr = categoryPolicy.policies.python.available {
      stdlib.categoryPolicies.python.available = true;
    };
    expected = true;
  };

  testCategoryPolicyUnavailableByDefault = {
    expr = categoryPolicy.policies.python.available { };
    expected = false;
  };

  testCategoryPolicyNonLanguagePresetUnbound = {
    expr =
      categoryPolicy.forPresetPath [
        "ci"
        "language-matrix"
      ] == null;
    expected = true;
  };

  testPythonPresetInheritsWhenInertWithoutPython = {
    expr =
      let
        cfg = eval {
          stdlib.report.enable = false;
        };
      in
      {
        triggered = cfg.presets.python.lint.ruff.result.triggered;
        applied = cfg.presets.python.lint.ruff.result.applied;
        ruff = (cfg.tools.ruff or { }).enable or false;
      };
    expected = {
      triggered = false;
      applied = false;
      ruff = false;
    };
  };

  testPythonPresetAppliesWhenLanguageEnabled = {
    expr =
      let
        cfg = eval {
          languages.python.enable = true;
          stdlib.report.enable = false;
        };
      in
      {
        applied = cfg.presets.python.lint.ruff.result.applied;
        ruff = cfg.tools.ruff.enable;
        hook = (cfg.git-hooks.hooks.ruff or { }).enable or false;
      };
    expected = {
      applied = true;
      ruff = true;
      hook = true;
    };
  };

  testPythonPresetAppliesWhenOverrideAvailable = {
    expr =
      let
        cfg = eval {
          stdlib.categoryPolicies.python.available = true;
          stdlib.report.enable = false;
        };
      in
      cfg.presets.python.lint.ruff.result.applied;
    expected = true;
  };

  testPythonToolEnableWithoutPythonFailsAssertion = {
    expr =
      let
        cfg = evalTool {
          tools.ruff.enable = true;
        };
        msgs = failedAssertions cfg;
      in
      {
        failed = msgs != [ ];
        mentionsPython = lib.any (m: lib.hasInfix "category python" m) msgs;
      };
    expected = {
      failed = true;
      mentionsPython = true;
    };
  };

  testPythonToolEnableWithLanguagePasses = {
    expr =
      let
        cfg = evalTool {
          languages.python.enable = true;
          tools.ruff.enable = true;
        };
      in
      failedAssertions cfg;
    expected = [ ];
  };

  testPythonToolEnableWithOverridePasses = {
    expr =
      let
        cfg = evalTool {
          stdlib.categoryPolicies.python.available = true;
          tools.ruff.enable = true;
        };
      in
      failedAssertions cfg;
    expected = [ ];
  };

  testBindPresetAppendsRequires = {
    expr =
      let
        bound = categoryPolicy.bindPreset {
          path = [
            "python"
            "lint"
            "ruff"
          ];
        };
        checked = bound.requires;
      in
      {
        inheritWhen = bound.when { } == false;
        inheritWhenOn = bound.when { languages.python.enable = true; };
        nRequires = builtins.length checked;
        message = (builtins.head checked).message;
      };
    expected = {
      inheritWhen = true;
      inheritWhenOn = true;
      nRequires = 1;
      message = ''
        category python: python must be available (set languages.python.enable or stdlib.categoryPolicies.python.available = true)
      '';
    };
  };
}
