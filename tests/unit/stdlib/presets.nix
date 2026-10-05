# Additive P2 coverage: strict throw, strict=false inert warning, node-scoped exclude.
# Preset identity is nested attrpaths (presets.terminal.quake), not flat strings.
{ lib, ... }:
let
  pe = import ../../lib/preset-eval.nix { inherit lib; };
  inherit (pe) presetLib eval sort;

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

  testToolsRejectStringLiterals = {
    expr =
      let
        toolLib = import ../../../stdlib/tool.nix { inherit lib; };
        tools = toolLib.refsFromPaths [
          [
            "python"
            "lint"
            "pyright"
          ]
        ];
        bad = builtins.tryEval (presetLib.normalizeTool "pyright");
        good = presetLib.normalizeTool tools.python.lint.pyright;
      in
      {
        rejectsString = !bad.success;
        inherit (good) name path;
      };
    expected = {
      rejectsString = true;
      name = "pyright";
      path = [
        "python"
        "lint"
        "pyright"
      ];
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
