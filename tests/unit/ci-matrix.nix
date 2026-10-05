# stdlib.ci.matrix IR + GHA backend.
{
  lib,
  ci,
  versions,
  contains,
  ...
}:
let
  inherit (ci) matrix;
  gha = ci.backends.github_actions;
in
{
  testMatrixCartesian = {
    expr = matrix.expand {
      dimensions = {
        runner = [
          "ubuntu-lts-prev"
          "ubuntu-lts-curr"
        ];
        toolchain = [
          "3.12"
          "3.13"
        ];
      };
    };
    # attrNames sorted: runner then toolchain.
    expected = [
      {
        runner = "ubuntu-lts-prev";
        toolchain = "3.12";
        optional = false;
      }
      {
        runner = "ubuntu-lts-prev";
        toolchain = "3.13";
        optional = false;
      }
      {
        runner = "ubuntu-lts-curr";
        toolchain = "3.12";
        optional = false;
      }
      {
        runner = "ubuntu-lts-curr";
        toolchain = "3.13";
        optional = false;
      }
    ];
  };

  testMatrixExcludePartial = {
    expr = matrix.expand {
      dimensions = {
        runner = [
          "a"
          "b"
        ];
        impl = [
          "cpython"
          "pypy"
        ];
      };
      exclude = [
        {
          impl = "pypy";
          runner = "b";
        }
      ];
    };
    # attrNames are sorted: impl then runner → cpython×{a,b}, pypy×{a,b}; drop pypy+b.
    expected = [
      {
        impl = "cpython";
        runner = "a";
        optional = false;
      }
      {
        impl = "cpython";
        runner = "b";
        optional = false;
      }
      {
        impl = "pypy";
        runner = "a";
        optional = false;
      }
    ];
  };

  testMatrixExplicitAllow = {
    expr = matrix.expand {
      expansion = "explicit";
      allow = [
        {
          runner = "ubuntu-lts-prev";
          toolchain = "3.12";
        }
        {
          runner = "ubuntu-lts-curr";
          toolchain = "3.13";
        }
      ];
    };
    expected = [
      {
        runner = "ubuntu-lts-prev";
        toolchain = "3.12";
        optional = false;
      }
      {
        runner = "ubuntu-lts-curr";
        toolchain = "3.13";
        optional = false;
      }
    ];
  };

  testMatrixIncludeAppends = {
    expr = matrix.expand {
      dimensions = {
        runner = [ "ubuntu-lts-prev" ];
        toolchain = [ "3.12" ];
      };
      include = [
        {
          runner = "gpu-self-hosted";
          toolchain = "3.13";
          optional = true;
        }
      ];
    };
    expected = [
      {
        runner = "ubuntu-lts-prev";
        toolchain = "3.12";
        optional = false;
      }
      {
        runner = "gpu-self-hosted";
        toolchain = "3.13";
        optional = true;
      }
    ];
  };

  testMatrixSeedsCrossRunners = {
    expr = matrix.expand {
      seeds = [
        {
          implementation = "cpython";
          version = "3.12";
        }
      ];
      dimensions = {
        runner = [
          "ubuntu-lts-prev"
          "ubuntu-lts-curr"
        ];
      };
    };
    expected = [
      {
        implementation = "cpython";
        version = "3.12";
        runner = "ubuntu-lts-prev";
        optional = false;
      }
      {
        implementation = "cpython";
        version = "3.12";
        runner = "ubuntu-lts-curr";
        optional = false;
      }
    ];
  };

  testMatrixMissingProviderBagThrows = {
    expr = builtins.tryEval (
      matrix.requireProviderBag {
        strict = true;
        runnerProfiles = {
          bare = {
            os = "linux";
            providers = { };
          };
        };
        provider = "github_actions";
        profileId = "bare";
      }
    );
    expected = {
      success = false;
      value = false;
    };
  };

  testMatrixDefaultProfilesHaveGha = {
    expr =
      let
        p = matrix.defaultRunnerProfiles;
      in
      {
        prevGha = p.ubuntu-lts-prev.providers.github_actions.runs-on;
        currGha = p.ubuntu-lts-curr.providers.github_actions.runs-on;
        prevProviders = lib.attrNames p.ubuntu-lts-prev.providers;
        arch = p.ubuntu-lts-curr.arch;
      };
    expected = {
      prevGha = [ "ubuntu-24.04" ];
      currGha = [ "ubuntu-26.04" ];
      prevProviders = [ "github_actions" ];
      arch = "x86_64";
    };
  };

  testLanguagePlanRendersLikeWorkflowText = {
    expr =
      let
        args = {
          pythonOn = true;
          python = versions.emptyPython // {
            min = "3.12";
          };
        };
        plan = versions.languageMatrixPlan args;
        viaPlan = gha.render plan;
        viaShim = versions.workflowText args;
      in
      {
        equal = viaPlan == viaShim;
        hasPython = contains "python:" viaPlan;
        hasOs = contains "ubuntu-24.04" viaPlan;
        cellCount = lib.length plan.jobs.python.cells;
      };
    expected = {
      equal = true;
      hasPython = true;
      hasOs = true;
      cellCount = 2; # two LTS runners × one python version
    };
  };

  testGhaOptionalIsPerCell = {
    expr =
      let
        plan = matrix.plan {
          runnerProfiles = matrix.defaultRunnerProfiles;
          jobs.mixed = {
            command = "true";
            dimensions = {
              runner = [ "ubuntu-lts-prev" ];
            };
            seeds = [ { toolchain = "3.12"; } ];
            include = [
              {
                runner = "ubuntu-lts-curr";
                toolchain = "3.13";
                optional = true;
              }
            ];
          };
        };
        yaml = gha.render plan;
      in
      {
        # Required cells must not make the whole job continue-on-error: true.
        jobLevelTrue = contains "continue-on-error: true\n" yaml;
        perCell = contains "continue-on-error: \${{ matrix.optional }}" yaml;
        optionalTrueRow = contains "optional: true" yaml;
        optionalFalseRow = contains "optional: false" yaml;
        # Default language matrix stays free of optional keys.
        pythonClean =
          !(contains "optional:" (
            versions.workflowText {
              pythonOn = true;
              python = versions.emptyPython // {
                min = "3.12";
              };
            }
          ));
      };
    expected = {
      jobLevelTrue = false;
      perCell = true;
      optionalTrueRow = true;
      optionalFalseRow = true;
      pythonClean = true;
    };
  };

  testGhaPreservesMultiLabelRunsOn = {
    expr =
      let
        plan = matrix.plan {
          runnerProfiles.gpu = {
            os = "linux";
            arch = "x86_64";
            providers.github_actions.runs-on = [
              "self-hosted"
              "linux"
              "x64"
              "gpu"
            ];
          };
          jobs.gpu = {
            command = "true";
            dimensions.runner = [ "gpu" ];
            seeds = [ { version = "1"; } ];
          };
        };
        yaml = gha.render plan;
        pythonYaml = versions.workflowText {
          pythonOn = true;
          python = versions.emptyPython // {
            min = "3.12";
          };
        };
      in
      {
        multiLabel = contains ''os: ["self-hosted", "linux", "x64", "gpu"]'' yaml;
        # Single-label default profiles stay scalars (actionlint-typed as string).
        singleLabelScalar = contains ''os: "ubuntu-24.04"'' pythonYaml;
        notOneElemList = !(contains ''os: ["ubuntu-24.04"]'' pythonYaml);
        notHeadOnly = !(contains ''os: "self-hosted"'' yaml);
      };
    expected = {
      multiLabel = true;
      singleLabelScalar = true;
      notOneElemList = true;
      notHeadOnly = true;
    };
  };

  # CodeRabbit: scalars must use toJSON so embedded quotes stay YAML-safe.
  testGhaMatrixScalarsUseToJson = {
    expr =
      let
        plan = matrix.plan {
          runnerProfiles = matrix.defaultRunnerProfiles;
          jobs.quoted = {
            command = "true";
            dimensions.runner = [ "ubuntu-lts-prev" ];
            seeds = [ { version = ''3.12"beta''; } ];
          };
        };
        yaml = gha.render plan;
        row = gha.matrixRow {
          os = "ubuntu-24.04";
          version = ''3.12"beta'';
          optional = true;
        };
      in
      {
        # JSON/YAML escape: 3.12\"beta, not the broken "3.12"beta" form.
        escapedInRender = contains ''version: "3.12\"beta"'' yaml;
        brokenForm = contains ''version: "3.12"beta"'' yaml;
        rowEscaped = contains ''version: "3.12\"beta"'' row;
        boolUnquoted = contains "optional: true" row;
      };
    expected = {
      escapedInRender = true;
      brokenForm = false;
      rowEscaped = true;
      boolUnquoted = true;
    };
  };

  # CodeRabbit: multiline job.command → block scalar; keep | prefix; single-line plain.
  testGhaMultilineCommandIsBlockScalar = {
    expr =
      let
        mk =
          command:
          gha.render (
            matrix.plan {
              runnerProfiles = matrix.defaultRunnerProfiles;
              jobs.cmd = {
                inherit command;
                dimensions.runner = [ "ubuntu-lts-prev" ];
                seeds = [ { version = "1"; } ];
              };
            }
          );
        multi = mk "echo one\necho two";
        already = mk "|\n              echo already";
        single = mk "true";
        # Match the Test step specifically (workflow also has other run: | steps).
        testStep = "name: Test\n        run: ";
      in
      {
        multiHasBlock = contains "${testStep}|\n                echo one\n                echo two" multi;
        multiNotInline = !(contains "${testStep}echo one\necho two" multi);
        alreadyKeepsPrefix = contains "${testStep}|\n                echo already" already;
        singlePlain = contains "${testStep}true" single;
      };
    expected = {
      multiHasBlock = true;
      multiNotInline = true;
      alreadyKeepsPrefix = true;
      singlePlain = true;
    };
  };

  # CodeRabbit (outside diff): emptyWorkflow must not flatten multi-label runs-on.
  testGhaEmptyWorkflowKeepsMultiLabelProfiles = {
    expr =
      let
        multiPlan = matrix.plan {
          runnerProfiles = {
            gpu = {
              os = "linux";
              arch = "x86_64";
              providers.github_actions.runs-on = [
                "self-hosted"
                "linux"
                "gpu"
              ];
            };
            inherit (matrix.defaultRunnerProfiles) ubuntu-lts-prev;
          };
          jobs = { };
        };
        yaml = gha.emptyWorkflow multiPlan;
        defaultEmpty = versions.workflowText { };
      in
      {
        # Full label list is one matrix.os value (include form).
        includeForm = contains "include:" yaml;
        fullList = contains ''os: ["self-hosted", "linux", "gpu"]'' yaml;
        # Must not flatten into separate single-label os entries.
        flatSelfHosted = contains ''os: "self-hosted"'' yaml;
        flatGpuOnly = contains "os: [self-hosted, linux, gpu]" yaml;
        # Default empty matrix stays the compact preferred LTS form.
        defaultCompact = contains ''os: ["ubuntu-24.04", "ubuntu-26.04"]'' defaultEmpty;
      };
    expected = {
      includeForm = true;
      fullList = true;
      flatSelfHosted = false;
      flatGpuOnly = false;
      defaultCompact = true;
    };
  };

  testMatrixMaxCellsThrows = {
    expr = builtins.tryEval (
      matrix.expand {
        dimensions = {
          a = [
            "1"
            "2"
          ];
          b = [
            "x"
            "y"
          ];
        };
        strategy.maxCells = 3;
      }
    );
    expected = {
      success = false;
      value = false;
    };
  };
}
