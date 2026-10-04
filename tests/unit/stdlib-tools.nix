# Additive P1 checks: mkTool metadata, nested categories, profiler placement.
# Does not evaluate Home Manager or nixpkgs.
{ lib, ... }:
let
  stdlib = import ../../stdlib { inherit lib; };
  discovered = stdlib.mkTool.specs (stdlib.discover [ ../../tools ]);
  byName = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
  spec = name: byName.${name}.spec;
  valgrind = spec "valgrind";
  cargoValgrind = spec "cargo-valgrind";
  cpu = lib.sort (a: b: a < b) (
    map (d: d.spec.name) (lib.filter (d: d.spec.category == "profilers.cpu") discovered)
  );
  memory = lib.sort (a: b: a < b) (
    map (d: d.spec.name) (lib.filter (d: d.spec.category == "profilers.memory") discovered)
  );
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

  testStdlibNoToolUsesFlatProfilerCategory = {
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

  testStdlibCpuProfilers = {
    expr = cpu;
    expected = [
      "cargo-flamegraph"
      "pprof"
      "py-spy"
      "samply"
    ];
  };

  testStdlibMemoryProfilers = {
    expr = memory;
    expected = [
      "cargo-valgrind"
      "valgrind"
    ];
  };

  testStdlibValgrindInstall = {
    expr = {
      inherit (valgrind) category upgrade;
      inherit (valgrind.install) attr kind;
    };
    expected = {
      category = "profilers.memory";
      attr = "valgrind";
      kind = "nix";
      upgrade = "flake";
    };
  };

  testStdlibCargoValgrindDependsOnValgrind = {
    expr = {
      inherit (cargoValgrind) category dependsOn;
      inherit (cargoValgrind.install) attr;
    };
    expected = {
      category = "profilers.memory";
      attr = "cargo-valgrind";
      dependsOn = [ "valgrind" ];
    };
  };

  testStdlibMigratedToolCategories = {
    expr = {
      alacritty = (spec "alacritty").category;
      warp = (spec "warp").category;
      zellij = (spec "zellij").category;
      bash = (spec "bash").category;
      zsh = (spec "zsh").category;
      elvish = (spec "elvish").category;
      atuin = (spec "atuin").category;
      blesh = (spec "blesh").category;
      starship = (spec "starship").category;
      cursor = (spec "cursor").category;
      vscode = (spec "vscode").category;
      neovim = (spec "neovim").category;
      nano = (spec "nano").category;
      neovimInstall = (spec "neovim").install;
    };
    expected = {
      alacritty = "terminal";
      warp = "terminal";
      zellij = "terminal.mux";
      bash = "shell";
      zsh = "shell";
      elvish = "shell";
      atuin = "shell.history";
      blesh = "shell";
      starship = "shell.prompt";
      cursor = "ide";
      vscode = "ide";
      neovim = "ide";
      nano = "ide";
      neovimInstall = {
        kind = "hm-program";
        program = "nixvim";
      };
    };
  };

  testStdlibShellToolsDefaults = {
    expr = {
      bash = (spec "bash").defaultEnable;
      zsh = (spec "zsh").defaultEnable;
      elvish = (spec "elvish").defaultEnable;
      registered = lib.sort (a: b: a < b) (stdlib.categories.resolve "shell").tools;
    };
    expected = {
      bash = true;
      zsh = false;
      elvish = false;
      registered = [
        "bash"
        "blesh"
        "elvish"
        "zsh"
      ];
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

  testStdlibCursorUpgradeIsSelf = {
    expr = (spec "cursor").upgrade;
    expected = "self";
  };

  testStdlibCoderabbitIsOpenVsxExtension = {
    expr =
      let
        cr = spec "coderabbit";
      in
      {
        inherit (cr)
          category
          upgrade
          defaultEnable
          path
          ;
        inherit (cr.install)
          kind
          publisher
          extension
          registry
          ;
      };
    expected = {
      category = "ide";
      upgrade = "catalog";
      defaultEnable = true;
      kind = "vscode-extension";
      publisher = "coderabbit";
      extension = "coderabbit-vscode";
      registry = "open-vsx";
      path = [
        "ide"
        "coderabbit"
      ];
    };
  };

  testStdlibCoderabbitCliIsBinary = {
    expr =
      let
        cr = spec "coderabbit-cli";
      in
      {
        inherit (cr)
          category
          upgrade
          defaultEnable
          path
          ;
        inherit (cr.install) kind;
      };
    expected = {
      category = "ide";
      upgrade = "self";
      defaultEnable = true;
      kind = "binary";
      path = [
        "ide"
        "coderabbit-cli"
      ];
    };
  };

  testStdlibMemoryToolsAreNotCpu = {
    expr = lib.any (
      d:
      d.spec.category == "profilers.cpu" && (d.spec.name == "valgrind" || d.spec.name == "cargo-valgrind")
    ) discovered;
    expected = false;
  };

  testStdlibProfilersOffByDefault = {
    expr = {
      valgrind = valgrind.defaultEnable;
      cargo-valgrind = cargoValgrind.defaultEnable;
      samply = (spec "samply").defaultEnable;
    };
    expected = {
      valgrind = false;
      cargo-valgrind = false;
      samply = false;
    };
  };

  testStdlibHarnessToolsAreNotLoaded = {
    expr = byName ? opencode || byName ? claude-code || byName ? codex;
    expected = false;
  };

  testStdlibLocalLangTools = {
    expr =
      let
        ruff = spec "ruff";
        prettier = spec "prettier";
        rustfmt = spec "rustfmt";
        checkPython = spec "check-python";
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
        checkPython = {
          inherit (checkPython) category isLocal;
        };
        denIgnoresLocal =
          let
            denMods = stdlib.den.load [ ../../tools ];
            # den.load still returns modules for global tools; local names are absent.
            names = map (d: d.spec.name) (lib.filter (d: d.spec.isLocal) discovered);
          in
          {
            hasLocalFiles = names != [ ];
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
      checkPython = {
        category = "lang.python";
        isLocal = true;
      };
      denIgnoresLocal = {
        hasLocalFiles = true;
        denNonEmpty = true;
      };
    };
  };

  testStdlibLocalToolNames = {
    expr = lib.sort (a: b: a < b) (map (d: d.spec.name) (lib.filter (d: d.spec.isLocal) discovered));
    expected = [
      "check-python"
      "clippy"
      "debug-statements"
      "gofmt"
      "golangci-lint"
      "prettier"
      "pyright"
      "ruff"
      "rustfmt"
      "sort-requirements-txt"
      "ty"
    ];
  };

  testStdlibToolAttrpathsMirrorCategories = {
    expr =
      let
        refs = stdlib.mkTool.refsFromSpecs discovered;
      in
      {
        pyright = (spec "pyright").path;
        ruff = (spec "ruff").path;
        bash = (spec "bash").path;
        atuin = (spec "atuin").path;
        blesh = (spec "blesh").path;
        samply = (spec "samply").path;
        ref = refs.python.lint.pyright.path;
      };
    expected = {
      pyright = [
        "python"
        "lint"
        "pyright"
      ];
      ruff = [
        "python"
        "lint"
        "ruff"
      ];
      bash = [
        "shell"
        "bash"
      ];
      atuin = [
        "shell"
        "history"
        "atuin"
      ];
      blesh = [
        "shell"
        "blesh"
      ];
      samply = [
        "profilers"
        "cpu"
        "samply"
      ];
      ref = [
        "python"
        "lint"
        "pyright"
      ];
    };
  };
}
