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

  # CodeRabbit: multiline → block scalar; keep | prefix; always JSON-quote singles.
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
        colonSpace = mk "echo foo: bar";
        hashComment = mk "printf '%s\\n' 'hello # world'";
        # Match the Test step specifically (workflow also has other run: | steps).
        testStep = "name: Test\n        run: ";
      in
      {
        multiHasBlock = contains "${testStep}|\n                echo one\n                echo two" multi;
        multiNotInline = !(contains "${testStep}echo one\necho two" multi);
        alreadyKeepsPrefix = contains "${testStep}|\n                echo already" already;
        singleQuoted = contains ''${testStep}"true"'' single;
        singleNotPlain = !(contains "${testStep}true\n" single);
        colonSpaceQuoted = contains ''${testStep}"echo foo: bar"'' colonSpace;
        colonSpaceNotPlain = !(contains "${testStep}echo foo: bar" colonSpace);
        hashQuoted = contains ''${testStep}"printf '%s\\n' 'hello # world'"'' hashComment;
        hashNotPlain = !(contains "${testStep}printf '%s\\n' 'hello # world'" hashComment);
      };
    expected = {
      multiHasBlock = true;
      multiNotInline = true;
      alreadyKeepsPrefix = true;
      singleQuoted = true;
      singleNotPlain = true;
      colonSpaceQuoted = true;
      colonSpaceNotPlain = true;
      hashQuoted = true;
      hashNotPlain = true;
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

  # M3: arch-filtered profiles + fixture/process dimensions (opt-in).
  testMatrixProfilesForArches = {
    expr =
      let
        x86 = matrix.profilesForArches matrix.allRunnerProfiles [ "x86_64" ];
        arm = matrix.profilesForArches matrix.allRunnerProfiles [ "aarch64" ];
        both = matrix.profilesForArches matrix.allRunnerProfiles [
          "x86_64"
          "aarch64"
        ];
      in
      {
        x86Ids = matrix.runnerIds x86;
        armIds = matrix.runnerIds arm;
        bothCount = lib.length (lib.attrNames both);
        armRunsOn = arm.ubuntu-lts-prev-aarch64.providers.github_actions.runs-on;
      };
    expected = {
      x86Ids = [
        "ubuntu-lts-prev"
        "ubuntu-lts-curr"
      ];
      armIds = [
        "ubuntu-lts-prev-aarch64"
        "ubuntu-lts-curr-aarch64"
      ];
      bothCount = 4;
      armRunsOn = [ "ubuntu-24.04-arm" ];
    };
  };

  testMatrixFixtureProcessCartesian = {
    expr = matrix.expand {
      dimensions = {
        runner = [ "ubuntu-lts-curr" ];
        fixture = [
          "none"
          "postgres"
        ];
        process = [ "default" ];
      };
      seeds = [ { version = "3.12"; } ];
    };
    expected = [
      {
        version = "3.12";
        fixture = "none";
        process = "default";
        runner = "ubuntu-lts-curr";
        optional = false;
      }
      {
        version = "3.12";
        fixture = "postgres";
        process = "default";
        runner = "ubuntu-lts-curr";
        optional = false;
      }
    ];
  };

  testLanguagePlanFixtureArchOptIn = {
    expr =
      let
        baseArgs = {
          pythonOn = true;
          python = versions.emptyPython // {
            min = "3.12";
          };
        };
        defaultPlan = versions.languageMatrixPlan baseArgs;
        richPlan = versions.languageMatrixPlan (
          baseArgs
          // {
            fixtures = [
              "none"
              "postgres"
            ];
            processes = [ "default" ];
            arches = [
              "x86_64"
              "aarch64"
            ];
          }
        );
        yaml = gha.render richPlan;
        rep = matrix.report richPlan;
      in
      {
        defaultCells = lib.length defaultPlan.jobs.python.cells;
        # 1 python × 4 runners × 2 fixtures × 1 process
        richCells = lib.length richPlan.jobs.python.cells;
        hasFixture = contains "fixture: \"postgres\"" yaml;
        hasArmOs = contains "ubuntu-24.04-arm" yaml;
        reportArches = rep.arches;
        reportFixtures = rep.fixtures;
      };
    expected = {
      defaultCells = 2;
      richCells = 8;
      hasFixture = true;
      hasArmOs = true;
      reportArches = [
        "aarch64"
        "x86_64"
      ];
      reportFixtures = [
        "none"
        "postgres"
      ];
    };
  };

  testDefaultFixtureProcessCatalogs = {
    expr = {
      fixtures = lib.attrNames matrix.defaultFixtureProfiles;
      processes = lib.attrNames matrix.defaultProcessProfiles;
      postgresSvc = matrix.defaultFixtureProfiles.postgres.services.postgres.enable;
    };
    expected = {
      fixtures = [
        "none"
        "postgres"
      ];
      processes = [ "default" ];
      postgresSvc = true;
    };
  };

  # Empty arches filter must not green-pass via no-language workflow.
  testLanguagePlanEmptyRunnersThrows = {
    expr = builtins.tryEval (
      versions.languageMatrixPlan {
        pythonOn = true;
        python = versions.emptyPython // {
          min = "3.12";
        };
        arches = [ "arm64" ]; # typo — catalog uses aarch64
      }
    );
    expected = {
      success = false;
      value = false;
    };
  };

  # M5: schedule / PR expansion profiles (slim PR vs full schedule).
  testExpansionProfilePrSlimesRunners = {
    expr =
      let
        full = matrix.plan {
          runnerProfiles = matrix.defaultRunnerProfiles;
          jobs.python = {
            command = "true";
            dimensions.runner = [
              "ubuntu-lts-prev"
              "ubuntu-lts-curr"
            ];
            seeds = [
              { version = "3.12"; }
              { version = "3.13"; }
            ];
          };
        };
        pr = matrix.forProfile full "pr";
        schedule = matrix.forProfile full "schedule";
      in
      {
        fullCount = lib.length full.jobs.python.cells;
        prCount = lib.length pr.jobs.python.cells;
        prRunners = lib.unique (map (c: c.runner) pr.jobs.python.cells);
        scheduleCount = lib.length schedule.jobs.python.cells;
        active = pr.activeProfile;
      };
    expected = {
      fullCount = 4;
      prCount = 2;
      prRunners = [ "ubuntu-lts-curr" ];
      scheduleCount = 4;
      active = "pr";
    };
  };

  testLanguagePlanExpansionProfile = {
    expr =
      let
        args = {
          pythonOn = true;
          python = versions.emptyPython // {
            min = "3.12";
          };
        };
        full = versions.languageMatrixPlan args;
        pr = versions.languageMatrixPlan (args // { expansionProfile = "pr"; });
      in
      {
        fullCells = lib.length full.jobs.python.cells;
        prCells = lib.length pr.jobs.python.cells;
        inherit ((lib.head pr.jobs.python.cells)) runner;
      };
    expected = {
      fullCells = 2;
      prCells = 1;
      runner = "ubuntu-lts-curr";
    };
  };

  testExpansionProfileJobOverlay = {
    expr =
      let
        full = matrix.plan {
          runnerProfiles = matrix.defaultRunnerProfiles;
          jobs.python = {
            command = "true";
            dimensions.runner = [
              "ubuntu-lts-prev"
              "ubuntu-lts-curr"
            ];
            seeds = [ { version = "3.12"; } ];
            expansionProfiles.pr = {
              match = {
                runner = "ubuntu-lts-prev";
              };
            };
          };
        };
        pr = matrix.forProfile full "pr";
      in
      {
        # Job overlay replaces default pr matchAny with match on prev.
        inherit ((lib.head pr.jobs.python.cells)) runner;
        count = lib.length pr.jobs.python.cells;
      };
    expected = {
      runner = "ubuntu-lts-prev";
      count = 1;
    };
  };

  # Custom runner ids: pr selects by release metadata, not fixed ubuntu-lts-curr.
  testExpansionProfilePrUsesRunnerMetadata = {
    expr =
      let
        full = matrix.plan {
          runnerProfiles = {
            corp-prev = {
              os = "linux";
              distro = "ubuntu";
              release = "24.04";
              arch = "x86_64";
              providers.github_actions.runs-on = [ "ubuntu-24.04" ];
            };
            corp-curr = {
              os = "linux";
              distro = "ubuntu";
              release = "26.04";
              arch = "x86_64";
              providers.github_actions.runs-on = [ "ubuntu-26.04" ];
            };
          };
          jobs.python = {
            command = "true";
            dimensions.runner = [
              "corp-prev"
              "corp-curr"
            ];
            seeds = [ { version = "3.12"; } ];
          };
        };
        pr = matrix.forProfile full "pr";
      in
      {
        prCount = lib.length pr.jobs.python.cells;
        inherit ((lib.head pr.jobs.python.cells)) runner;
        resolved = matrix.currentLtsRunnerIds full.runnerProfiles;
      };
    expected = {
      prCount = 1;
      runner = "corp-curr";
      resolved = [ "corp-curr" ];
    };
  };

  testExpansionProfilePrEmptyWithoutLtsMetaThrows = {
    expr = builtins.tryEval (
      matrix.forProfile (matrix.plan {
        runnerProfiles = {
          bare = {
            os = "linux";
            arch = "x86_64";
            providers.github_actions.runs-on = [ "ubuntu-26.04" ];
          };
        };
        jobs.python = {
          command = "true";
          dimensions.runner = [ "bare" ];
          seeds = [ { version = "3.12"; } ];
        };
      }) "pr"
    );
    expected = {
      success = false;
      value = false;
    };
  };

  testLanguagePlanArchesFilterRunnerProfilesOverride = {
    expr =
      let
        plan = versions.languageMatrixPlan {
          pythonOn = true;
          python = versions.emptyPython // {
            min = "3.12";
          };
          arches = [ "aarch64" ];
          runnerProfiles = matrix.allRunnerProfiles;
        };
      in
      lib.unique (map (c: matrix.allRunnerProfiles.${c.runner}.arch) plan.jobs.python.cells);
    expected = [ "aarch64" ];
  };
}
