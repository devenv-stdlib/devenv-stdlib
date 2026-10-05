# stdlib.ci.matrix IR + GHA/CircleCI backends.
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
  cci = ci.backends.circleci;
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

  testMatrixDefaultProfilesHaveGhaAndCircleci = {
    expr =
      let
        p = matrix.defaultRunnerProfiles;
      in
      {
        prevGha = p.ubuntu-lts-prev.providers.github_actions.runs-on;
        currGha = p.ubuntu-lts-curr.providers.github_actions.runs-on;
        prevCci = p.ubuntu-lts-prev.providers.circleci.resource_class;
        arch = p.ubuntu-lts-curr.arch;
      };
    expected = {
      prevGha = [ "ubuntu-24.04" ];
      currGha = [ "ubuntu-26.04" ];
      prevCci = "medium";
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

  testCircleciBackendStub = {
    expr =
      let
        r = cci.render (matrix.plan { jobs = { }; });
      in
      {
        inherit (r) implemented path;
        textNull = r.text == null;
        mentionsStub = contains "stub" r.message;
      };
    expected = {
      implemented = false;
      path = ".circleci/config.yml";
      textNull = true;
      mentionsStub = true;
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
        # Single-label default profiles still render (as a one-element YAML list).
        singleLabelList = contains ''os: ["ubuntu-24.04"]'' pythonYaml;
        notHeadOnly = !(contains ''os: "self-hosted"'' yaml);
      };
    expected = {
      multiLabel = true;
      singleLabelList = true;
      notHeadOnly = true;
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
