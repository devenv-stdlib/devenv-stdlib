# Additive P2 coverage: strict throw, strict=false inert warning, node-scoped exclude.
{ lib, ... }:
let
  presetLib = import ../../stdlib/preset.nix { inherit lib; };

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
    options.den.aspects = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
    };
    options.den.policies = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
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
    name = "demo";
    requires = [
      {
        assertion = false;
        message = "demo requirement unmet";
      }
    ];
  };

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
        result = (eval strictPreset { presets.demo.strict = false; }).config.presets.demo.result;
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
        result = (eval (import ../../presets/terminal-quake.nix) { }).config.presets.terminal-quake.result;
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
        result = (eval (import ../../presets/ide.nix) { }).config.presets.ide.result;
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

  testAlacrittyAtuinRequiresBothTools = {
    expr =
      let
        ok = (eval (import ../../presets/alacritty-atuin.nix) { }).config.presets.alacritty-atuin.result;
        dropped = presetLib.mkPreset {
          name = "alacritty-atuin";
          tools = [ "atuin" ];
          requires = [
            {
              assertion = cfg: builtins.elem "blesh" (cfg.presets.alacritty-atuin.tools or [ ]);
              message = "alacritty-atuin requires the blesh tool to be enabled";
            }
          ];
          extraOptions.tools = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "atuin" ];
          };
        };
      in
      {
        inherit (ok) applied;
        tools = sort ok.includeTools;
        threw = !(builtins.tryEval (eval dropped { }).config.presets.alacritty-atuin.result).success;
      };
    expected = {
      applied = true;
      tools = [
        "atuin"
        "blesh"
      ];
      threw = true;
    };
  };

  testHostHmOnlyGuardExcludesOsHostsOnly = {
    expr =
      let
        result =
          (eval (import ../../presets/host-hm-only-guard.nix) {
            presets.host-hm-only-guard.hostClass = "nixos";
            presets.host-hm-only-guard.selected = [ "terminal" ];
          }).config.presets.host-hm-only-guard.result;
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
          name = "demo-when";
          when = cfg: cfg.languages.python.enable or false;
          requires = [
            {
              assertion = false;
              message = "must not fire when the trigger is off";
            }
          ];
        };
        result = (eval quiet { }).config.presets.demo-when.result;
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
}
