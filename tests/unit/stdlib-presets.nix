# Additive P2 coverage: strict throw, strict=false inert warning, node-scoped exclude.
# Preset identity is nested attrpaths (presets.terminal.quake), not flat strings.
{ lib, ... }:
let
  presetLib = import ../../stdlib/preset.nix { inherit lib; };
  shellLib = import ../../stdlib/shell.nix { inherit lib; };

  denStub = {
    lib.policy = {
      include = value: {
        __policyEffect = "include";
        inherit value;
      };
      exclude = value: {
        __policyEffect = "exclude";
        inherit value;
      };
    };
    aspects = { };
  };

  denOptions = {
    options = {
      den = {
        aspects = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.raw;
          default = { };
        };
        policies = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.raw;
          default = { };
        };
      };
      tools = {
        bash.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        zsh.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        elvish.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };
      shell.preferred = shellLib.preferredOption;
    };
  };

  eval =
    presetModule: extra:
    lib.evalModules {
      specialArgs.den = denStub;
      modules = [
        denOptions
        presetModule
        extra
      ];
    };

  # Default fixture: bash is the sole enabled shell tool (option optional).
  withBash = {
    tools.bash.enable = true;
  };

  sort = names: lib.sort (a: b: a < b) names;

  nestedTree = {
    alpha = {
      cardinality = "exactly-one";
      tools = [
        "left"
        "right"
      ];
      children.nested = {
        cardinality = "exactly-one";
        tools = [
          "nested-a"
          "nested-b"
        ];
      };
    };
    beta = {
      cardinality = "exactly-one";
      tools = [ "cousin" ];
    };
  };

  strictPreset = presetLib.mkPreset {
    path = [ "demo" ];
    requires = [
      {
        assertion = false;
        message = "demo requirement unmet";
      }
    ];
  };

  # Example registry for attrpath includes.
  presets = presetLib.refsFromPaths [
    [
      "python"
      "lint"
      "ruff"
    ]
    [
      "terminal"
      "quake"
    ]
  ];

in
{
  testPresetStrictEvalThrows = {
    expr =
      let
        warned = (eval strictPreset { presets.demo.strict = false; }).config.presets.demo.result.inert;
        threw = !(builtins.tryEval (eval strictPreset { }).config.presets.demo.result).success;
      in
      warned && threw;
    expected = true;
  };

  testPresetStrictFalseWarnsAndInert = {
    expr =
      let
        inherit ((eval strictPreset { presets.demo.strict = false; }).config.presets.demo) result;
      in
      {
        inherit (result)
          inert
          applied
          includeTools
          excludeTools
          ;
        warned = lib.any (text: lib.hasInfix "demo requirement unmet" text) result.warnings;
      };
    expected = {
      inert = true;
      applied = false;
      includeTools = [ ];
      excludeTools = [ ];
      warned = true;
    };
  };

  testNestedCategoryExcludeDoesNotCrossBranches = {
    expr =
      let
        nested = presetLib.categoryExcludes nestedTree [ "nested-a" ];
        parent = presetLib.categoryExcludes nestedTree [ "left" ];
      in
      {
        nested = sort nested;
        parent = sort parent;
        nestedCrosses = sort (
          lib.intersectLists nested [
            "left"
            "right"
            "cousin"
          ]
        );
        parentCrosses = sort (
          lib.intersectLists parent [
            "nested-a"
            "nested-b"
            "cousin"
          ]
        );
      };
    expected = {
      nested = [ "nested-b" ];
      parent = [ "right" ];
      nestedCrosses = [ ];
      parentCrosses = [ ];
    };
  };

  testTerminalQuakeExcludeStaysOnTerminalNode = {
    expr =
      let
        inherit ((eval (import ../../presets/terminal/quake.nix) { }).config.presets.terminal.quake) result;
      in
      {
        inherit (result) includeTools;
        excludeTools = sort result.excludeTools;
        excludeAspects = sort (result.excludeAspects { });
        includeAspects = sort result.includeAspects;
        crosses = lib.intersectLists result.excludeTools [
          "zellij"
          "atuin"
          "cursor"
        ];
      };
    expected = {
      includeTools = [ "alacritty" ];
      excludeTools = [ "warp" ];
      excludeAspects = [ "warp" ];
      includeAspects = [ "alacritty" ];
      crosses = [ ];
    };
  };

  testIdePresetDoesNotExcludeSiblingIdes = {
    expr =
      let
        inherit ((eval (import ../../presets/ide.nix) { }).config.presets.ide) result;
      in
      {
        includeTools = sort result.includeTools;
        inherit (result) excludeTools;
      };
    expected = {
      includeTools = [
        "cursor"
        "neovim"
        "vscode"
      ];
      excludeTools = [ ];
    };
  };

  testAlacrittyAtuinSingleShellOptionOptional = {
    expr =
      let
        ok =
          (eval (import ../../presets/terminal/alacritty-atuin.nix) withBash)
          .config.presets.terminal.alacritty-atuin;
        resolved = shellLib.resolve withBash ok.shell;
      in
      {
        inherit (ok.result) applied;
        tools = sort ok.result.includeTools;
        shellOption = ok.shell;
        inherit resolved;
        blesh = shellLib.shouldInstallBlesh resolved;
      };
    expected = {
      applied = true;
      tools = [
        "atuin"
        "bash"
        "blesh"
      ];
      shellOption = null;
      resolved = "bash";
      blesh = true;
    };
  };

  testAlacrittyAtuinMultiShellBleShOnlyBash = {
    expr =
      let
        multi = {
          tools.bash.enable = true;
          tools.zsh.enable = true;
        };
        onBash =
          (eval (import ../../presets/terminal/alacritty-atuin.nix) (
            multi // { presets.terminal.alacritty-atuin.shell = "bash"; }
          )).config.presets.terminal.alacritty-atuin.result;
        onZsh =
          (eval (import ../../presets/terminal/alacritty-atuin.nix) (
            multi // { presets.terminal.alacritty-atuin.shell = "zsh"; }
          )).config.presets.terminal.alacritty-atuin.result;
        missingShellExpr =
          (eval (import ../../presets/terminal/alacritty-atuin.nix) multi)
          .config.presets.terminal.alacritty-atuin.result;
        missingShell = builtins.tryEval missingShellExpr;
      in
      {
        bashTools = sort onBash.includeTools;
        zshTools = sort onZsh.includeTools;
        bashHasBlesh = builtins.elem "blesh" onBash.includeTools;
        zshHasBlesh = builtins.elem "blesh" onZsh.includeTools;
        mandatory = !missingShell.success;
      };
    expected = {
      bashTools = [
        "atuin"
        "bash"
        "blesh"
        "zsh"
      ];
      zshTools = [
        "atuin"
        "bash"
        "zsh"
      ];
      bashHasBlesh = true;
      zshHasBlesh = false;
      mandatory = true;
    };
  };

  testAlacrittyAtuinNoBashSkipsBlesh = {
    expr =
      let
        zshOnly = {
          tools.zsh.enable = true;
        };
        ok =
          (eval (import ../../presets/terminal/alacritty-atuin.nix) zshOnly)
          .config.presets.terminal.alacritty-atuin;
        resolved = shellLib.resolve zshOnly ok.shell;
      in
      {
        inherit (ok.result) applied;
        tools = sort ok.result.includeTools;
        inherit resolved;
        blesh = builtins.elem "blesh" ok.result.includeTools;
      };
    expected = {
      applied = true;
      tools = [
        "atuin"
        "zsh"
      ];
      resolved = "zsh";
      blesh = false;
    };
  };

  testHostHmOnlyGuardExcludesOsHostsOnly = {
    expr =
      let
        inherit
          ((eval (import ../../presets/host/hm-only-guard.nix) {
            presets.host.hm-only-guard.hostClass = "nixos";
            presets.host.hm-only-guard.selected = [ "terminal" ];
          }).config.presets.host.hm-only-guard
          )
          result
          ;
        banned = [
          "alacritty-quake"
          "terminal"
          "warp-quake"
        ];
      in
      {
        inherit (result) applied;
        nixos = sort (result.excludeAspects { host.class = "nixos"; });
        darwin = sort (result.excludeAspects { host.system = "aarch64-darwin"; });
        home = result.excludeAspects { };
        cousins = lib.intersectLists (result.excludeAspects { host.class = "darwin"; }) [
          "cursor"
          "zellij"
        ];
        coversSelected = result.applied && banned == sort (result.excludeAspects { host.class = "nixos"; });
      };
    expected = {
      applied = true;
      nixos = [
        "alacritty-quake"
        "terminal"
        "warp-quake"
      ];
      darwin = [
        "alacritty-quake"
        "terminal"
        "warp-quake"
      ];
      home = [ ];
      cousins = [ ];
      coversSelected = true;
    };
  };

  testPresetWhenFalseIsInertWithoutWarning = {
    expr =
      let
        quiet = presetLib.mkPreset {
          path = [
            "demo"
            "when"
          ];
          when = cfg: cfg.languages.python.enable or false;
          requires = [
            {
              assertion = false;
              message = "must not fire when the trigger is off";
            }
          ];
        };
        inherit ((eval quiet { }).config.presets.demo.when) result;
      in
      {
        inherit (result)
          inert
          applied
          triggered
          warnings
          ;
      };
    expected = {
      inert = true;
      applied = false;
      triggered = false;
      warnings = [ ];
    };
  };

  testIncludesRejectStringLiterals = {
    expr =
      let
        bad = builtins.tryEval (presetLib.normalizeInclude "ruff");
        good = presetLib.normalizeInclude presets.python.lint.ruff;
      in
      {
        rejectsString = !bad.success;
        attrpath = good;
      };
    expected = {
      rejectsString = true;
      attrpath = "python.lint.ruff";
    };
  };

  testRefsFromPathsAreAttrpaths = {
    expr = {
      ruff = presets.python.lint.ruff.path;
      quake = presets.terminal.quake.path;
    };
    expected = {
      ruff = [
        "python"
        "lint"
        "ruff"
      ];
      quake = [
        "terminal"
        "quake"
      ];
    };
  };
}
