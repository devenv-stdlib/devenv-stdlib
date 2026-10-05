# mkTool / discover / shell API coverage against mock-framework tools only.
# Real tool inventories live in per-owner suites under tools/**/tests/unit.
{ lib, ... }:
let
  stdlib = import ../../../stdlib { inherit lib; };
  mock = import ../../lib/mock-framework.nix { inherit lib; };
  discovered = stdlib.mkTool.specs (stdlib.discover [ mock.tools ]);
  byName = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
  spec = name: byName.${name}.spec;
  names = lib.sort (a: b: a < b) (map (d: d.spec.name) discovered);
  byCategory =
    cat:
    lib.sort (a: b: a < b) (map (d: d.spec.name) (lib.filter (d: d.spec.category == cat) discovered));
in
{
  testStdlibTerminalCategoryExactlyOne = {
    expr = (stdlib.categories.resolve "terminal").cardinality;
    expected = "exactly-one";
  };

  testStdlibProfilerNodesAreBundles = {
    expr = {
      cpu = (stdlib.categories.resolve "profilers.cpu").cardinality;
      memory = (stdlib.categories.resolve "profilers.memory").cardinality;
    };
    expected = {
      cpu = "bundle";
      memory = "bundle";
    };
  };

  testMockDiscoverSkipsUnderscoreDirs = {
    expr = {
      inherit names;
      hasIgnored = byName ? "not-a-tool";
    };
    expected = {
      names = [
        "mock-alt"
        "mock-bash"
        "mock-check"
        "mock-cpu"
        "mock-ext"
        "mock-hist"
        "mock-ide"
        "mock-mem"
        "mock-mem-dep"
        "mock-prettier"
        "mock-pyright"
        "mock-ruff"
        "mock-rustfmt"
        "mock-term"
        "mock-zsh"
      ];
      hasIgnored = false;
    };
  };

  testMockNoToolUsesFlatProfilerCategory = {
    expr = lib.any (d: d.spec.category == "profilers") discovered;
    expected = false;
  };

  testStdlibUnknownCategoryRejected = {
    expr =
      (builtins.tryEval (
        stdlib.mkTool.meta {
          name = "nope";
          category = "cli.nope";
          install = {
            kind = "nix";
            attr = "hello";
          };
          upgrade = "flake";
        }
      )).success;
    expected = false;
  };

  testMockProfilerCategories = {
    expr = {
      cpu = byCategory "profilers.cpu";
      memory = byCategory "profilers.memory";
    };
    expected = {
      cpu = [ "mock-cpu" ];
      memory = [
        "mock-mem"
        "mock-mem-dep"
      ];
    };
  };

  testMockMemDepDependsOnMem = {
    expr = {
      inherit ((spec "mock-mem-dep")) category dependsOn;
      inherit ((spec "mock-mem-dep").install) attr;
    };
    expected = {
      category = "profilers.memory";
      dependsOn = [ "mock-mem" ];
      attr = "hello";
    };
  };

  testMockToolCategoriesAndInstallKinds = {
    expr = {
      term = (spec "mock-term").category;
      altDefault = (spec "mock-alt").defaultEnable;
      bash = (spec "mock-bash").category;
      hist = (spec "mock-hist").category;
      ide = {
        inherit ((spec "mock-ide")) category upgrade;
        inherit ((spec "mock-ide").install) kind program;
      };
      ext = {
        inherit ((spec "mock-ext")) upgrade;
        inherit ((spec "mock-ext").install)
          kind
          publisher
          extension
          registry
          ;
      };
    };
    expected = {
      term = "terminal";
      altDefault = false;
      bash = "shell";
      hist = "shell.history";
      ide = {
        category = "ide";
        upgrade = "self";
        kind = "hm-program";
        program = "mock-ide";
      };
      ext = {
        upgrade = "catalog";
        kind = "vscode-extension";
        publisher = "mock";
        extension = "mock-ext";
        registry = "open-vsx";
      };
    };
  };

  testStdlibShellResolveSingleDefault = {
    expr =
      let
        inherit (stdlib) shell;
        config = {
          tools = {
            bash.enable = true;
            zsh.enable = false;
            elvish.enable = false;
          };
        };
      in
      {
        resolved = shell.resolve config null;
        optional = shell.soleEnabled config == "bash";
        blesh = shell.shouldInstallBlesh (shell.resolve config null);
      };
    expected = {
      resolved = "bash";
      optional = true;
      blesh = true;
    };
  };

  testStdlibShellMultiBleShOnlyBash = {
    expr =
      let
        inherit (stdlib) shell;
        config = {
          tools = {
            bash.enable = true;
            zsh.enable = true;
            elvish.enable = false;
          };
        };
        resolvedBash = shell.resolve config "bash";
        resolvedZsh = shell.resolve config "zsh";
        policy = shell.policyShells config resolvedBash;
      in
      {
        policy = lib.sort (a: b: a < b) policy;
        bleshOnBash = shell.shouldInstallBlesh resolvedBash;
        bleshOnZsh = shell.shouldInstallBlesh resolvedZsh;
        integrations = shell.enableIntegrations policy;
      };
    expected = {
      policy = [
        "bash"
        "zsh"
      ];
      bleshOnBash = true;
      bleshOnZsh = false;
      integrations = {
        enableBashIntegration = true;
        enableZshIntegration = true;
      };
    };
  };

  testStdlibShellNoBashSkipsBlesh = {
    expr =
      let
        inherit (stdlib) shell;
        config = {
          tools = {
            bash.enable = false;
            zsh.enable = true;
            elvish.enable = false;
          };
        };
        resolved = shell.resolve config null;
      in
      {
        inherit resolved;
        blesh = shell.shouldInstallBlesh resolved;
        mandatoryWithoutOption = shell.resolve {
          tools = {
            bash.enable = false;
            zsh.enable = true;
            elvish.enable = true;
          };
        } null;
      };
    expected = {
      resolved = "zsh";
      blesh = false;
      mandatoryWithoutOption = null;
    };
  };

  testMockProfilersOffByDefault = {
    expr = {
      cpu = (spec "mock-cpu").defaultEnable;
      mem = (spec "mock-mem").defaultEnable;
    };
    expected = {
      cpu = false;
      mem = false;
    };
  };

  testMockLocalLangTools = {
    expr =
      let
        ruff = spec "mock-ruff";
        prettier = spec "mock-prettier";
        rustfmt = spec "mock-rustfmt";
        check = spec "mock-check";
      in
      {
        ruff = {
          inherit (ruff)
            category
            scopes
            isLocal
            isGlobal
            ;
          inherit (ruff.install) kind;
          inherit (ruff) upgrade;
        };
        prettier.category = prettier.category;
        rustfmt.category = rustfmt.category;
        check = {
          inherit (check) category isLocal;
        };
        denIgnoresLocal =
          let
            denMods = stdlib.den.load [ mock.tools ];
            localNames = map (d: d.spec.name) (lib.filter (d: d.spec.isLocal) discovered);
          in
          {
            hasLocalFiles = localNames != [ ];
            denNonEmpty = denMods != [ ];
          };
      };
    expected = {
      ruff = {
        category = "lang.python.linters";
        scopes = [ "local" ];
        isLocal = true;
        isGlobal = false;
        kind = "project";
        upgrade = "none";
      };
      prettier.category = "lang.javascript.linters";
      rustfmt.category = "lang.rust.linters";
      check = {
        category = "lang.python";
        isLocal = true;
      };
      denIgnoresLocal = {
        hasLocalFiles = true;
        denNonEmpty = true;
      };
    };
  };

  testMockLocalToolNames = {
    expr = lib.sort (a: b: a < b) (map (d: d.spec.name) (lib.filter (d: d.spec.isLocal) discovered));
    expected = [
      "mock-check"
      "mock-prettier"
      "mock-pyright"
      "mock-ruff"
      "mock-rustfmt"
    ];
  };

  testMockToolAttrpathsMirrorCategories = {
    expr =
      let
        refs = stdlib.mkTool.refsFromSpecs discovered;
      in
      {
        pyright = (spec "mock-pyright").path;
        ruff = (spec "mock-ruff").path;
        bash = (spec "mock-bash").path;
        hist = (spec "mock-hist").path;
        cpu = (spec "mock-cpu").path;
        ref = refs.python.lint.mock-pyright.path;
      };
    expected = {
      pyright = [
        "python"
        "lint"
        "mock-pyright"
      ];
      ruff = [
        "python"
        "lint"
        "mock-ruff"
      ];
      bash = [
        "shell"
        "mock-bash"
      ];
      hist = [
        "shell"
        "history"
        "mock-hist"
      ];
      cpu = [
        "profilers"
        "cpu"
        "mock-cpu"
      ];
      ref = [
        "python"
        "lint"
        "mock-pyright"
      ];
    };
  };
}
