{
  lib,
  config,
  ...
}:
let
  project = import ./project-lib.nix { inherit lib; };
  dlib = import ./debtmap-lib.nix { inherit lib; };
  enabled = project.debtmapLanguages (config.languages or { });

  godLimits =
    defaults:
    lib.types.submodule {
      options = {
        maxMethods = lib.mkOption {
          type = lib.types.ints.positive;
          default = defaults.maxMethods;
          description = "Maximum methods before a type is a god object.";
        };
        maxFields = lib.mkOption {
          type = lib.types.ints.positive;
          default = defaults.maxFields;
          description = "Maximum fields before a type is a god object.";
        };
      };
    };
in
{
  options.debtmap = {
    thresholds = {
      complexity = lib.mkOption {
        type = lib.types.ints.positive;
        default = dlib.official.thresholds.complexity;
      };
      duplication = lib.mkOption {
        type = lib.types.ints.positive;
        default = dlib.official.thresholds.duplication;
      };
      maxFileLength = lib.mkOption {
        type = lib.types.ints.positive;
        default = dlib.official.thresholds.maxFileLength;
      };
      maxFunctionLength = lib.mkOption {
        type = lib.types.ints.positive;
        default = dlib.official.thresholds.maxFunctionLength;
      };
      minimumDebtScore = lib.mkOption {
        type = lib.types.float;
        default = dlib.official.thresholds.minimumDebtScore;
      };
      minimumCyclomaticComplexity = lib.mkOption {
        type = lib.types.ints.positive;
        default = dlib.official.thresholds.minimumCyclomaticComplexity;
      };
      minimumCognitiveComplexity = lib.mkOption {
        type = lib.types.ints.positive;
        default = dlib.official.thresholds.minimumCognitiveComplexity;
      };
      minimumRiskScore = lib.mkOption {
        type = lib.types.float;
        default = dlib.official.thresholds.minimumRiskScore;
      };
      validation = {
        maxAverageComplexity = lib.mkOption {
          type = lib.types.float;
          default = dlib.official.thresholds.validation.maxAverageComplexity;
        };
        maxDebtDensity = lib.mkOption {
          type = lib.types.float;
          default = dlib.official.thresholds.validation.maxDebtDensity;
        };
        maxCodebaseRiskScore = lib.mkOption {
          type = lib.types.float;
          default = dlib.official.thresholds.validation.maxCodebaseRiskScore;
        };
        minCoveragePercentage = lib.mkOption {
          type = lib.types.float;
          default = dlib.official.thresholds.validation.minCoveragePercentage;
        };
        maxTotalDebtScore = lib.mkOption {
          type = lib.types.ints.positive;
          default = dlib.official.thresholds.validation.maxTotalDebtScore;
        };
      };
    };

    ignore.patterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        Paths debtmap skips. Defaults follow the official example, plus
        language-specific entries for enabled languages.* (target, venv,
        node_modules, vendor). Set this to replace the list.
      '';
    };

    output.defaultFormat = lib.mkOption {
      type = lib.types.enum [
        "json"
        "markdown"
        "terminal"
      ];
      default = dlib.official.defaultFormat;
      description = "debtmap analyze output format (pre-commit uses this file).";
    };

    entropy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = dlib.official.entropy.enable;
      };
      weight = lib.mkOption {
        type = lib.types.float;
        default = dlib.official.entropy.weight;
      };
      minTokens = lib.mkOption {
        type = lib.types.ints.positive;
        default = dlib.official.entropy.minTokens;
      };
      patternThreshold = lib.mkOption {
        type = lib.types.float;
        default = dlib.official.entropy.patternThreshold;
      };
    };

    constructors = {
      patterns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = dlib.official.constructors.patterns;
      };
      maxCyclomatic = lib.mkOption {
        type = lib.types.ints.positive;
        default = dlib.official.constructors.maxCyclomatic;
      };
      maxCognitive = lib.mkOption {
        type = lib.types.ints.positive;
        default = dlib.official.constructors.maxCognitive;
      };
      maxLength = lib.mkOption {
        type = lib.types.ints.positive;
        default = dlib.official.constructors.maxLength;
      };
      maxNesting = lib.mkOption {
        type = lib.types.ints.positive;
        default = dlib.official.constructors.maxNesting;
      };
    };

    godObjectDetection = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      rust = lib.mkOption {
        type = godLimits dlib.defaultGodObject.rust;
        default = { };
      };
      python = lib.mkOption {
        type = godLimits dlib.defaultGodObject.python;
        default = { };
      };
      javascript = lib.mkOption {
        type = godLimits dlib.defaultGodObject.javascript;
        default = { };
        description = "Used for JavaScript and TypeScript (debtmap shares this table).";
      };
      go = lib.mkOption {
        type = godLimits dlib.defaultGodObject.go;
        default = { };
      };
    };

    scoring = {
      coverage = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "Scoring weight; set with complexity and dependency so they sum to 1.0.";
      };
      complexity = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
      };
      dependency = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
      };
    };

    extra = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Merged last into the generated .debtmap.toml attrset.";
    };
  };

  config = {
    debtmap.ignore.patterns = lib.mkDefault (dlib.ignorePatterns enabled);

    # Regenerated on devenv:files from languages.* and debtmap.*. Do not edit.
    files.".debtmap.toml".toml = dlib.toToml {
      inherit enabled;
      inherit (config.debtmap)
        thresholds
        extra
        ;
      inherit (config.debtmap) entropy constructors scoring;
      inherit (config.debtmap) godObjectDetection;
      inherit (config.debtmap.output) defaultFormat;
      ignorePatterns = config.debtmap.ignore.patterns;
    };
  };
}
