# Additive coverage for category-wide policies (python first instance).
# Exercise bindPreset/realize and mkTool.apply assertions directly (no full
# devenv.load tools+presets eval).
{ lib, ... }:
let
  stdlib = import ../../stdlib { inherit lib; };
  categoryPolicy = stdlib.categoryPolicy;
  presetLib = import ../../stdlib/preset.nix { inherit lib; };
  toolLib = import ../../stdlib/tool.nix { inherit lib; };

  pythonPolicy = categoryPolicy.policies.python;

  realizePreset =
    {
      path,
      when ? null,
      requires ? [ ],
      enable ? true,
      strict ? true,
      cfg ? { },
    }:
    let
      bound = categoryPolicy.bindPreset { inherit path when requires; };
    in
    presetLib.realize {
      name = presetLib.pathString path;
      when = bound.when;
      requires = bound.requires;
      tools = [ "ruff" ];
      inherit enable strict cfg;
      globalStrict = cfg.presets.strict or true;
    };

  # Minimal apply module eval for one global tool under lang.python.linters.
  evalRuffTool =
    extra:
    (lib.evalModules {
      modules = [
        categoryPolicy.optionsModule
        {
          options = {
            languages = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options.enable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                  };
                }
              );
              default = { };
            };
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
            };
            home.packages = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
            };
          };
          config = extra;
        }
        (
          {
            pkgs ? { },
            lib,
            config,
            ...
          }:
          toolLib.apply { inherit pkgs lib config; } {
            name = "ruff";
            category = "lang.python.linters";
            install = {
              kind = "nix";
              attr = "hello";
            };
            upgrade = "flake";
            homeManager = _: { };
          }
        )
      ];
    }).config;

  failedMessages = cfg: map (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions);
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
    expr = pythonPolicy.available {
      languages.python.enable = true;
    };
    expected = true;
  };

  testCategoryPolicyAvailableViaOverride = {
    expr = pythonPolicy.available {
      stdlib.categoryPolicies.python.available = true;
    };
    expected = true;
  };

  testCategoryPolicyUnavailableByDefault = {
    expr = pythonPolicy.available { };
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
        d = realizePreset {
          path = [
            "python"
            "lint"
            "ruff"
          ];
        };
      in
      {
        inherit (d) triggered applied;
        tools = d.includeTools;
      };
    expected = {
      triggered = false;
      applied = false;
      tools = [ ];
    };
  };

  testPythonPresetAppliesWhenLanguageEnabled = {
    expr =
      let
        d = realizePreset {
          path = [
            "python"
            "lint"
            "ruff"
          ];
          cfg = {
            languages.python.enable = true;
          };
        };
      in
      {
        inherit (d) applied;
        tools = d.includeTools;
      };
    expected = {
      applied = true;
      tools = [ "ruff" ];
    };
  };

  testPythonPresetAppliesWhenOverrideAvailable = {
    expr =
      (realizePreset {
        path = [
          "python"
          "lint"
          "ruff"
        ];
        cfg = {
          stdlib.categoryPolicies.python.available = true;
        };
      }).applied;
    expected = true;
  };

  testPythonPresetExplicitWhenStillRequiresCategory = {
    expr =
      let
        # Force when=true without python → triggered, then requires fail (strict throw).
        threw = !(builtins.tryEval (
          realizePreset {
            path = [
              "python"
              "lint"
              "ruff"
            ];
            when = _: true;
            cfg = { };
          }
        )).success;
        warned = realizePreset {
          path = [
            "python"
            "lint"
            "ruff"
          ];
          when = _: true;
          strict = false;
          cfg = { };
        };
      in
      {
        inherit threw;
        inert = warned.inert;
        hasWarning = lib.any (w: lib.hasInfix "category python" w) warned.warnings;
      };
    expected = {
      threw = true;
      inert = true;
      hasWarning = true;
    };
  };

  testPythonToolEnableWithoutPythonFailsAssertion = {
    expr =
      let
        cfg = evalRuffTool {
          tools.ruff.enable = true;
        };
        msgs = failedMessages cfg;
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
    expr = failedMessages (evalRuffTool {
      languages.python.enable = true;
      tools.ruff.enable = true;
    });
    expected = [ ];
  };

  testPythonToolEnableWithOverridePasses = {
    expr = failedMessages (evalRuffTool {
      stdlib.categoryPolicies.python.available = true;
      tools.ruff.enable = true;
    });
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

  testToolAssertionsHelper = {
    expr =
      let
        bad = categoryPolicy.toolAssertions { } "lang.python.linters";
        good = categoryPolicy.toolAssertions {
          languages.python.enable = true;
        } "lang.python.linters";
      in
      {
        badFails = !(builtins.head bad).assertion;
        goodOk = (builtins.head good).assertion;
        unrelated = categoryPolicy.toolAssertions { } "shell" == [ ];
      };
    expected = {
      badFails = true;
      goodOk = true;
      unrelated = true;
    };
  };
}
