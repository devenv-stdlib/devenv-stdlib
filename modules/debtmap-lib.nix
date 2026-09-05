# Pure debtmap .debtmap.toml policy. Defaults follow
# https://github.com/iepathos/debtmap/blob/master/.debtmap.toml
{ lib }:
rec {
  ignoreShared = [
    "tests/**/*"
    "**/fixtures/**"
    "**/mocks/**"
    "**/stubs/**"
    "**/examples/**"
    "**/demo/**"
    "**/testdata/**"
  ];

  ignoreFor = {
    rust = [
      "target/**"
      "benches/**"
      "**/test_*.rs"
      "**/*_test.rs"
      "**/*_tests.rs"
      "**/*_demo.rs"
    ];
    python = [
      "venv/**"
      ".venv/**"
    ];
    javascript = [
      "node_modules/**"
      "*.min.js"
    ];
    typescript = [
      "node_modules/**"
      "*.min.js"
    ];
    go = [ "vendor/**" ];
  };

  ignorePatterns =
    enabled: lib.unique (ignoreShared ++ lib.concatMap (name: ignoreFor.${name} or [ ]) enabled);

  # TypeScript uses the javascript table (debtmap treats them the same).
  godObjectKey = name: if name == "typescript" then "javascript" else name;

  defaultGodObject = {
    rust = {
      maxMethods = 25;
      maxFields = 15;
    };
    python = {
      maxMethods = 20;
      maxFields = 20;
    };
    javascript = {
      maxMethods = 15;
      maxFields = 10;
    };
    go = {
      maxMethods = 20;
      maxFields = 15;
    };
  };

  official = {
    thresholds = {
      complexity = 10;
      duplication = 50;
      maxFileLength = 500;
      maxFunctionLength = 50;
      minimumDebtScore = 2.0;
      minimumCyclomaticComplexity = 3;
      minimumCognitiveComplexity = 5;
      minimumRiskScore = 2.0;
      validation = {
        maxAverageComplexity = 10.0;
        maxDebtDensity = 50.0;
        maxCodebaseRiskScore = 7.0;
        minCoveragePercentage = 0.0;
        maxTotalDebtScore = 10000;
      };
    };
    defaultFormat = "markdown";
    entropy = {
      enable = true;
      weight = 0.5;
      minTokens = 10;
      patternThreshold = 0.7;
    };
    constructors = {
      patterns = [
        "new"
        "default"
        "from_"
        "with_"
        "create_"
        "make_"
        "build_"
        "of_"
        "empty"
        "zero"
        "any"
      ];
      maxCyclomatic = 2;
      maxCognitive = 3;
      maxLength = 15;
      maxNesting = 1;
    };
    godObjectDetection = {
      enable = true;
    }
    // defaultGodObject;
    scoring = {
      coverage = null;
      complexity = null;
      dependency = null;
    };
  };

  sample =
    enabled:
    toToml {
      inherit enabled;
      inherit (official)
        thresholds
        entropy
        constructors
        godObjectDetection
        scoring
        defaultFormat
        ;
      ignorePatterns = ignorePatterns enabled;
    };

  godLimitsToml = limits: {
    max_methods = limits.maxMethods;
    max_fields = limits.maxFields;
  };

  toToml =
    {
      enabled,
      thresholds,
      ignorePatterns,
      defaultFormat,
      entropy,
      constructors,
      godObjectDetection,
      scoring,
      extra ? { },
    }:
    let
      godKeys = lib.unique (map godObjectKey enabled);
      godTables = lib.listToAttrs (
        map (name: {
          inherit name;
          value = godLimitsToml godObjectDetection.${name};
        }) godKeys
      );
      scoringSet = lib.filterAttrs (_: value: value != null) {
        inherit (scoring) coverage complexity dependency;
      };
      base = {
        thresholds = {
          inherit (thresholds) complexity duplication;
          max_file_length = thresholds.maxFileLength;
          max_function_length = thresholds.maxFunctionLength;
          minimum_debt_score = thresholds.minimumDebtScore;
          minimum_cyclomatic_complexity = thresholds.minimumCyclomaticComplexity;
          minimum_cognitive_complexity = thresholds.minimumCognitiveComplexity;
          minimum_risk_score = thresholds.minimumRiskScore;
          validation = {
            max_average_complexity = thresholds.validation.maxAverageComplexity;
            max_debt_density = thresholds.validation.maxDebtDensity;
            max_codebase_risk_score = thresholds.validation.maxCodebaseRiskScore;
            min_coverage_percentage = thresholds.validation.minCoveragePercentage;
            max_total_debt_score = thresholds.validation.maxTotalDebtScore;
          };
        };
        languages.enabled = enabled;
        ignore.patterns = ignorePatterns;
        output.default_format = defaultFormat;
        external_api = {
          detect_external_api = false;
          api_functions = [ ];
          api_files = [ ];
        };
        entropy = {
          enabled = entropy.enable;
          inherit (entropy) weight;
          min_tokens = entropy.minTokens;
          pattern_threshold = entropy.patternThreshold;
        };
        classification.constructors = {
          inherit (constructors) patterns;
          max_cyclomatic = constructors.maxCyclomatic;
          max_cognitive = constructors.maxCognitive;
          max_length = constructors.maxLength;
          max_nesting = constructors.maxNesting;
        };
        god_object_detection = {
          enabled = godObjectDetection.enable;
        }
        // godTables;
      }
      // lib.optionalAttrs (scoringSet != { }) { scoring = scoringSet; };
    in
    lib.recursiveUpdate base extra;
}
