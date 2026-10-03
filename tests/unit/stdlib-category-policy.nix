# Additive coverage for category-wide policies (python, rust, …).
# Exercise bindPreset/realize and mkTool.apply assertions directly (no full
# devenv.load tools+presets eval).
{ lib, ... }:
let
  stdlib = import ../../stdlib { inherit lib; };
  inherit (stdlib) categoryPolicy;
  presetLib = import ../../stdlib/preset.nix { inherit lib; };
  toolLib = import ../../stdlib/tool.nix { inherit lib; };

  goPolicy = categoryPolicy.policies.go;
  javascriptPolicy = categoryPolicy.policies.javascript;
  jsOrTsPolicy = categoryPolicy.policies.javascript-or-typescript;
  pythonPolicy = categoryPolicy.policies.python;
  rustPolicy = categoryPolicy.policies.rust;
  typescriptPolicy = categoryPolicy.policies.typescript;

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
      inherit (bound) when;
      inherit (bound) requires;
      tools = [
        [
          "python"
          "lint"
          "ruff"
        ]
      ];
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
      hasPython = lib.elem "python" categoryPolicy.policyIds;
      hasZig = lib.elem "zig" categoryPolicy.policyIds;
      hasJsOrTs = lib.elem "javascript-or-typescript" categoryPolicy.policyIds;
      hasPostgres = lib.elem "services.postgres" categoryPolicy.policyIds;
      nPolicies = builtins.length categoryPolicy.policyIds;
      preset =
        (categoryPolicy.forPresetPath [
          "python"
          "lint"
          "ruff"
        ]).id;
      tool = (categoryPolicy.forToolCategory "lang.python.linters").id;
      annotated = (stdlib.categories.resolve "lang.python").categoryPolicy;
    };
    expected = {
      # 58 languages + 43 services + javascript-or-typescript
      nPolicies = 102;
      hasPython = true;
      hasZig = true;
      hasJsOrTs = true;
      hasPostgres = true;
      preset = "python";
      tool = "python";
      annotated = "python";
    };
  };

  testCategoryPolicyHaskellNixAnnotated = {
    expr = {
      haskell = (stdlib.categories.resolve "lang.haskell").categoryPolicy;
      nix = (stdlib.categories.resolve "lang.nix").categoryPolicy;
      haskellTool = (categoryPolicy.forToolCategory "lang.haskell.linters").id;
      nixTool = (categoryPolicy.forToolCategory "lang.nix.linters").id;
    };
    expected = {
      haskell = "haskell";
      nix = "nix";
      haskellTool = "haskell";
      nixTool = "nix";
    };
  };

  testCategoryPolicyServiceAnnotated = {
    expr = {
      annotated = (stdlib.categories.resolve "services.postgres").categoryPolicy;
      tool = (categoryPolicy.forToolCategory "services.postgres").id;
      preset =
        (categoryPolicy.forPresetPath [
          "services"
          "postgres"
          "usql"
        ]).id;
      availableOff = categoryPolicy.policies."services.postgres".available { };
      availableOn = categoryPolicy.policies."services.postgres".available {
        services.postgres.enable = true;
      };
      availableOverride = categoryPolicy.policies."services.postgres".available {
        stdlib.categoryPolicies."services.postgres".available = true;
      };
    };
    expected = {
      annotated = "services.postgres";
      tool = "services.postgres";
      preset = "services.postgres";
      availableOff = false;
      availableOn = true;
      availableOverride = true;
    };
  };

  testCategoryPolicyJavascriptRegistered = {
    expr = {
      preset =
        (categoryPolicy.forPresetPath [
          "javascript"
          "debtmap"
        ]).id;
      tool = (categoryPolicy.forToolCategory "lang.javascript.linters").id;
      annotated = (stdlib.categories.resolve "lang.javascript").categoryPolicy;
      available = javascriptPolicy.available { languages.javascript.enable = true; };
      unavailable = javascriptPolicy.available { };
      sharedTsOnly = jsOrTsPolicy.available { languages.typescript.enable = true; };
      sharedNeither = jsOrTsPolicy.available { };
    };
    expected = {
      preset = "javascript";
      tool = "javascript";
      annotated = "javascript";
      available = true;
      unavailable = false;
      sharedTsOnly = true;
      sharedNeither = false;
    };
  };

  testJavascriptDebtmapInertWithoutJavascript = {
    expr =
      (realizePreset {
        path = [
          "javascript"
          "debtmap"
        ];
      }).triggered;
    expected = false;
  };

  testCategoryPolicyTypescriptRegistered = {
    expr = {
      preset =
        (categoryPolicy.forPresetPath [
          "typescript"
          "bundler"
        ]).id;
      tool = (categoryPolicy.forToolCategory "lang.typescript.linters").id;
      annotated = (stdlib.categories.resolve "lang.typescript").categoryPolicy;
      available = typescriptPolicy.available { languages.typescript.enable = true; };
      unavailable = typescriptPolicy.available { };
    };
    expected = {
      preset = "typescript";
      tool = "typescript";
      annotated = "typescript";
      available = true;
      unavailable = false;
    };
  };

  testTypescriptPresetInheritsWhenInertWithoutTypescript = {
    expr =
      (realizePreset {
        path = [
          "typescript"
          "debtmap"
        ];
      }).triggered;
    expected = false;
  };

  testTypescriptPresetAppliesWhenLanguageEnabled = {
    expr =
      (realizePreset {
        path = [
          "typescript"
          "debtmap"
        ];
        cfg = {
          languages.typescript.enable = true;
        };
      }).applied;
    expected = true;
  };

  testTypescriptBundlerKeepsLeafRequires = {
    expr =
      let
        bound = categoryPolicy.bindPreset {
          path = [
            "typescript"
            "bundler"
          ];
          requires = [
            {
              assertion = cfg: (cfg.typescript.bundler or null) != null;
              message = "bundler required";
            }
          ];
        };
      in
      {
        nRequires = builtins.length bound.requires;
        inheritWhen = bound.when { languages.typescript.enable = true; };
      };
    expected = {
      nRequires = 2;
      inheritWhen = true;
    };
  };

  testJavascriptSharedPresetAppliesForTypescriptOnly = {
    expr =
      let
        bound = categoryPolicy.bindPreset {
          path = [
            "javascript"
            "lint"
            "prettier"
          ];
          policy = "javascript-or-typescript";
        };
        d = presetLib.realize {
          name = "javascript.lint.prettier";
          inherit (bound) when;
          inherit (bound) requires;
          tools = [ ];
          enable = true;
          strict = true;
          cfg = {
            languages.typescript.enable = true;
          };
          globalStrict = true;
        };
      in
      {
        inherit (d) applied;
        inheritWhenTs = bound.when { languages.typescript.enable = true; };
        inheritWhenNeither = bound.when { };
      };
    expected = {
      applied = true;
      inheritWhenTs = true;
      inheritWhenNeither = false;
    };
  };

  testCategoryPolicyGoRegistered = {
    expr = {
      preset =
        (categoryPolicy.forPresetPath [
          "go"
          "lint"
          "gofmt"
        ]).id;
      tool = (categoryPolicy.forToolCategory "lang.go.linters").id;
      annotated = (stdlib.categories.resolve "lang.go").categoryPolicy;
      available = goPolicy.available { languages.go.enable = true; };
      unavailable = goPolicy.available { };
    };
    expected = {
      preset = "go";
      tool = "go";
      annotated = "go";
      available = true;
      unavailable = false;
    };
  };

  testGoPresetInheritsWhenInertWithoutGo = {
    expr =
      (realizePreset {
        path = [
          "go"
          "lint"
          "gofmt"
        ];
      }).triggered;
    expected = false;
  };

  testGoPresetAppliesWhenLanguageEnabled = {
    expr =
      (realizePreset {
        path = [
          "go"
          "lint"
          "gofmt"
        ];
        cfg = {
          languages.go.enable = true;
        };
      }).applied;
    expected = true;
  };

  testCategoryPolicyRustRegistered = {
    expr = {
      preset =
        (categoryPolicy.forPresetPath [
          "rust"
          "lint"
          "clippy"
        ]).id;
      tool = (categoryPolicy.forToolCategory "lang.rust.linters").id;
      annotated = (stdlib.categories.resolve "lang.rust").categoryPolicy;
      available = rustPolicy.available { languages.rust.enable = true; };
      unavailable = rustPolicy.available { };
    };
    expected = {
      preset = "rust";
      tool = "rust";
      annotated = "rust";
      available = true;
      unavailable = false;
    };
  };

  testRustPresetInheritsWhenInertWithoutRust = {
    expr =
      let
        d = realizePreset {
          path = [
            "rust"
            "lint"
            "clippy"
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

  testRustPresetAppliesWhenLanguageEnabled = {
    expr =
      (realizePreset {
        path = [
          "rust"
          "lint"
          "clippy"
        ];
        cfg = {
          languages.rust.enable = true;
        };
      }).applied;
    expected = true;
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
        threw =
          !(builtins.tryEval (realizePreset {
            path = [
              "python"
              "lint"
              "ruff"
            ];
            when = _: true;
            cfg = { };
          })).success;
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
        inherit (warned) inert;
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
        inherit ((builtins.head checked)) message;
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
        # Explicit policy id still binds (lang.shell.* tools / categoryPolicy = "shell").
        shellPolicy = categoryPolicy.toolAssertions { } "shell";
      in
      {
        badFails = !(builtins.head bad).assertion;
        goodOk = (builtins.head good).assertion;
        unrelated = categoryPolicy.toolAssertions { } "not-a-policy" == [ ];
        unboundNull = categoryPolicy.toolAssertions { } null == [ ];
        unboundFalse = categoryPolicy.toolAssertions { } false == [ ];
        shellExplicitFails = !(builtins.head shellPolicy).assertion;
      };
    expected = {
      badFails = true;
      goodOk = true;
      unrelated = true;
      unboundNull = true;
      unboundFalse = true;
      shellExplicitFails = true;
    };
  };

  # Interactive tools under tools/shell use category = "shell" without an
  # explicit categoryPolicy. That bare category must not bind to the devenv
  # languages.shell policy (Den enables bash by default).
  testToolPolicyArgSkipsBareShellCategory = {
    expr =
      let
        bareShell = toolLib.policyArgOf { category = "shell"; };
        dottedLang = toolLib.policyArgOf { category = "lang.python.linters"; };
        explicit = toolLib.policyArgOf {
          category = "lang.javascript.linters";
          categoryPolicy = "javascript-or-typescript";
        };
        unbound = toolLib.policyArgOf {
          category = "shell";
          categoryPolicy = false;
        };
      in
      {
        inherit
          bareShell
          dottedLang
          explicit
          unbound
          ;
        bareShellAssertions = categoryPolicy.toolAssertions { } bareShell == [ ];
      };
    expected = {
      bareShell = null;
      dottedLang = "lang.python.linters";
      explicit = "javascript-or-typescript";
      unbound = false;
      bareShellAssertions = true;
    };
  };
}
