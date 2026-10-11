{
  lib,
  debtmap,
  ...
}:
{
  testDebtmapSampleEmptyLanguages = {
    expr = (debtmap.sample [ ]).languages.enabled;
    expected = [ ];
  };

  testDebtmapSamplePythonEnabled = {
    expr = (debtmap.sample [ "python" ]).languages.enabled;
    expected = [ "python" ];
  };

  testDebtmapGodObjectOnlyEnabledLanguages = {
    expr = lib.attrNames (debtmap.sample [ "python" ]).god_object_detection;
    expected = [
      "enabled"
      "python"
    ];
  };

  testDebtmapTypescriptUsesJavascriptGodObject = {
    expr = lib.attrNames (debtmap.sample [ "typescript" ]).god_object_detection;
    expected = [
      "enabled"
      "javascript"
    ];
  };

  testDebtmapIgnorePythonHasVenvNotTarget = {
    expr = [
      (lib.elem "venv/**" (debtmap.ignorePatterns [ "python" ]))
      (lib.elem "target/**" (debtmap.ignorePatterns [ "python" ]))
      (lib.elem "target/**" (debtmap.ignorePatterns [ "rust" ]))
    ];
    expected = [
      true
      false
      true
    ];
  };

  testDebtmapOfficialComplexity = {
    expr = (debtmap.sample [ ]).thresholds.complexity;
    expected = 10;
  };

  testDebtmapOfficialFormat = {
    expr = (debtmap.sample [ ]).output.default_format;
    expected = "terminal";
  };

  testDebtmapScoringOmittedByDefault = {
    expr = (debtmap.sample [ ]) ? scoring;
    expected = false;
  };

  testDebtmapScoringWhenSet = {
    expr =
      (debtmap.toToml {
        enabled = [ "go" ];
        inherit (debtmap.official)
          thresholds
          entropy
          constructors
          godObjectDetection
          ;
        scoring = {
          coverage = 0.5;
          complexity = 0.35;
          dependency = 0.15;
        };
        ignorePatterns = [ ];
        defaultFormat = "json";
      }).scoring.coverage;
    expected = 0.5;
  };

  testDebtmapExtraOverridesFormat = {
    expr =
      (debtmap.toToml {
        enabled = [ ];
        inherit (debtmap.official)
          thresholds
          entropy
          constructors
          godObjectDetection
          scoring
          ;
        ignorePatterns = [ ];
        defaultFormat = "markdown";
        extra.output.default_format = "json";
      }).output.default_format;
    expected = "json";
  };
}
