# stdlib.ci.attachments IR + GHA slot merge.
{
  lib,
  ci,
  versions,
  contains,
  ...
}:
let
  inherit (ci) matrix attachments;
  gha = ci.backends.github_actions;

  basePlan = matrix.plan {
    runnerProfiles = matrix.defaultRunnerProfiles;
    jobs.python = {
      command = "true";
      dimensions.runner = [ "ubuntu-lts-prev" ];
      seeds = [ { version = "3.12"; } ];
    };
  };

  fakePlan = attachments.plan {
    caches = [
      {
        id = "fake-cache";
        languages = [ "rust" ];
        providers.github_actions = {
          uses = "example/cache-action@v1";
          slot = "pre-command";
          "with" = {
            path = "target";
          };
        };
      }
    ];
    coverage = [
      {
        id = "fake-cov";
        providers.github_actions = {
          uses = "example/codecov@v1";
          slot = "post-command";
          secrets = [ "CODECOV_TOKEN" ];
        };
      }
    ];
    reporting = [
      {
        id = "fake-report";
        providers.github_actions = {
          uses = "example/junit@v1";
          slot = "always";
          "with" = {
            files = "junit/**/*.xml";
          };
        };
      }
    ];
  };

  # Colon / special chars that break unquoted YAML scalars.
  awkwardPlan = attachments.plan {
    caches = [
      {
        id = "awk name: cache";
        providers.github_actions = {
          name = "restore: cache";
          uses = "example/cache@v1";
          slot = "pre-command";
          "with" = {
            path = "src: build";
          };
        };
      }
    ];
  };
in
{
  testAttachmentsEmptyPlanShape = {
    expr = attachments.emptyPlan;
    expected = {
      caches = [ ];
      coverage = [ ];
      reporting = [ ];
    };
  };

  testAttachmentsSlots = {
    expr = attachments.slots;
    expected = [
      "pre-toolchain"
      "pre-command"
      "post-command"
      "always"
    ];
  };

  # Empty AttachmentPlan must not change GHA language-matrix YAML.
  # Fixture pins MatrixPlan phase-1 jobYaml so base-template drift fails the suite
  # (emptyEqPlain alone compares two live renders and would miss shared drift).
  testGhaEmptyAttachmentPlanIsByteStable = {
    expr =
      let
        plain = gha.render basePlan;
        withEmpty = gha.render (basePlan // { attachments = attachments.emptyPlan; });
        withMissing = gha.render (removeAttrs basePlan [ "attachments" ]);
        fixture = builtins.readFile ../fixtures/ci/matrixplan-phase1-empty-attachments.yml;
      in
      {
        emptyEqPlain = withEmpty == plain;
        missingEqPlain = withMissing == plain;
        matchesFixture = withEmpty == fixture;
        # Also matches the versions.workflowText shim path.
        shimEq =
          plain == versions.workflowText {
            pythonOn = true;
            python = versions.emptyPython // {
              min = "3.12";
            };
          };
      };
    expected = {
      emptyEqPlain = true;
      missingEqPlain = true;
      matchesFixture = true;
      shimEq = false; # shim expands two LTS runners; basePlan is one cell
    };
  };

  # Narrower shim equality: same snapshot → identical YAML with empty attachments.
  testGhaEmptyAttachmentsMatchLanguageMatrixShim = {
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
        viaEmpty = gha.render (plan // { attachments = attachments.emptyPlan; });
        viaShim = versions.workflowText args;
      in
      {
        emptyEqPlan = viaEmpty == viaPlan;
        planEqShim = viaPlan == viaShim;
      };
    expected = {
      emptyEqPlan = true;
      planEqShim = true;
    };
  };

  testAttachmentsSelectByLanguageAndProvider = {
    expr =
      let
        rustCtx = {
          provider = "github_actions";
          language = "rust";
        };
        pythonCtx = {
          provider = "github_actions";
          language = "python";
        };
        selectedRust = map (a: a.id) (attachments.select fakePlan rustCtx);
        selectedPython = map (a: a.id) (attachments.select fakePlan pythonCtx);
        slotted = attachments.bySlot fakePlan rustCtx;
      in
      {
        inherit selectedRust selectedPython;
        preCommand = map (a: a.id) slotted.pre-command;
        postCommand = map (a: a.id) slotted.post-command;
        always = map (a: a.id) slotted.always;
        preToolchain = slotted.pre-toolchain;
      };
    expected = {
      selectedRust = [
        "fake-cache"
        "fake-cov"
        "fake-report"
      ];
      # rust-only cache dropped; coverage/reporting have no language filter.
      selectedPython = [
        "fake-cov"
        "fake-report"
      ];
      preCommand = [ "fake-cache" ];
      postCommand = [ "fake-cov" ];
      always = [ "fake-report" ];
      preToolchain = [ ];
    };
  };

  testGhaAttachmentSlotsAndSecrets = {
    expr =
      let
        plan =
          matrix.plan {
            runnerProfiles = matrix.defaultRunnerProfiles;
            jobs.rust = {
              command = "true";
              dimensions.runner = [ "ubuntu-lts-prev" ];
              seeds = [ { version = "stable"; } ];
            };
          }
          // {
            attachments = fakePlan;
          };
        yaml = gha.render plan;
        # Order anchors: cache before Test step, cov between Test and Save, report after Save.
        cacheAt = lib.strings.stringLength (lib.head (lib.splitString ''name: "fake-cache"'' yaml));
        testAt = lib.strings.stringLength (lib.head (lib.splitString "- name: Test\n" yaml));
        covAt = lib.strings.stringLength (lib.head (lib.splitString ''name: "fake-cov"'' yaml));
        saveAt = lib.strings.stringLength (lib.head (lib.splitString "- name: Save Nix store" yaml));
        reportAt = lib.strings.stringLength (lib.head (lib.splitString ''name: "fake-report"'' yaml));
      in
      {
        hasCache = contains ''uses: "example/cache-action@v1"'' yaml;
        hasCov = contains ''uses: "example/codecov@v1"'' yaml;
        hasReport = contains ''uses: "example/junit@v1"'' yaml;
        secretBinding = contains "CODECOV_TOKEN: \${{ secrets.CODECOV_TOKEN }}" yaml;
        # No raw secret values — only the secrets.* expression.
        noRawToken = !(contains "CODECOV_TOKEN: tok_" yaml);
        alwaysIf = contains "name: \"fake-report\"\n        if: \${{ always() }}" yaml;
        orderOk = cacheAt < testAt && testAt < covAt && covAt < saveAt && saveAt < reportAt;
      };
    expected = {
      hasCache = true;
      hasCov = true;
      hasReport = true;
      secretBinding = true;
      noRawToken = true;
      alwaysIf = true;
      orderOk = true;
    };
  };

  # CodeRabbit: with:/name/run values with colons must be YAML-safe scalars.
  testGhaAttachmentYamlSafeScalars = {
    expr =
      let
        plan =
          matrix.plan {
            runnerProfiles = matrix.defaultRunnerProfiles;
            jobs.python = {
              command = "true";
              dimensions.runner = [ "ubuntu-lts-prev" ];
              seeds = [ { version = "3.12"; } ];
            };
          }
          // {
            attachments = awkwardPlan;
          };
        yaml = gha.render plan;
      in
      {
        quotedName = contains ''name: "restore: cache"'' yaml;
        quotedPath = contains ''path: "src: build"'' yaml;
        # Unquoted form would be invalid YAML (`path: src: build`).
        brokenPath = contains "path: src: build" yaml;
        yamlScalarHelper = gha.yamlScalar "src: build";
      };
    expected = {
      quotedName = true;
      quotedPath = true;
      brokenPath = false;
      yamlScalarHelper = ''"src: build"'';
    };
  };

  # CodeRabbit: pre-toolchain before nix/devenv bootstrap; pre-command before Test.
  testGhaPreToolchainBeforeBootstrap = {
    expr =
      let
        plan =
          matrix.plan {
            runnerProfiles = matrix.defaultRunnerProfiles;
            jobs.rust = {
              command = "true";
              dimensions.runner = [ "ubuntu-lts-prev" ];
              seeds = [ { version = "stable"; } ];
            };
          }
          // {
            attachments = attachments.plan {
              caches = [
                {
                  id = "prep-tc";
                  providers.github_actions = {
                    uses = "example/prep@v1";
                    slot = "pre-toolchain";
                  };
                }
                {
                  id = "pre-cmd";
                  providers.github_actions = {
                    uses = "example/pre@v1";
                    slot = "pre-command";
                  };
                }
              ];
            };
          };
        yaml = gha.render plan;
        prepAt = lib.strings.stringLength (lib.head (lib.splitString ''name: "prep-tc"'' yaml));
        installNixAt = lib.strings.stringLength (
          lib.head (lib.splitString "uses: cachix/install-nix-action@v31" yaml)
        );
        preCmdAt = lib.strings.stringLength (lib.head (lib.splitString ''name: "pre-cmd"'' yaml));
        testAt = lib.strings.stringLength (lib.head (lib.splitString "- name: Test\n" yaml));
        devenvAt = lib.strings.stringLength (lib.head (lib.splitString "- name: Install devenv" yaml));
      in
      {
        prepBeforeNix = prepAt < installNixAt;
        preCmdAfterDevenv = preCmdAt > devenvAt;
        preCmdBeforeTest = preCmdAt < testAt;
      };
    expected = {
      prepBeforeNix = true;
      preCmdAfterDevenv = true;
      preCmdBeforeTest = true;
    };
  };

  # CodeRabbit: artifact uploads stay job steps (4-space post-dedent indent).
  testGhaAttachmentArtifactsAreJobSteps = {
    expr =
      let
        plan =
          matrix.plan {
            runnerProfiles = matrix.defaultRunnerProfiles;
            jobs.python = {
              command = "true";
              dimensions.runner = [ "ubuntu-lts-prev" ];
              seeds = [ { version = "3.12"; } ];
            };
          }
          // {
            attachments = attachments.plan {
              reporting = [
                {
                  id = "junit-pub";
                  providers.github_actions = {
                    uses = "example/junit@v1";
                    slot = "always";
                  };
                  artifacts = [
                    {
                      id = "junit";
                      path = "junit/**/*.xml";
                    }
                  ];
                }
              ];
            };
          };
        yaml = gha.render plan;
        # After padJob, steps are indented with 6 spaces before `-`.
        uploadStep = contains ''- name: "Upload junit"'' yaml;
        uploadUses = contains "uses: actions/upload-artifact@v4" yaml;
        quotedPath = contains ''path: "junit/**/*.xml"'' yaml;
        # Column-zero upload would sit outside steps.
        flushLeft = contains "\n- name: \"Upload junit\"" yaml;
      in
      {
        inherit
          uploadStep
          uploadUses
          quotedPath
          flushLeft
          ;
      };
    expected = {
      uploadStep = true;
      uploadUses = true;
      quotedPath = true;
      flushLeft = false;
    };
  };

  testGhaLanguageFilterSkipsRustOnlyCache = {
    expr =
      let
        plan = basePlan // {
          attachments = fakePlan;
        };
        yaml = gha.render plan;
      in
      {
        noCache = !(contains ''"fake-cache"'' yaml);
        hasCov = contains ''"fake-cov"'' yaml;
        hasReport = contains ''"fake-report"'' yaml;
      };
    expected = {
      noCache = true;
      hasCov = true;
      hasReport = true;
    };
  };

  testAttachmentsAutoEnablePhase1Empty = {
    expr = attachments.autoEnable { } {
      provider = "github_actions";
      forge = "github";
    };
    expected = [ ];
  };

  testAttachmentsResolveMergesUserOverAuto = {
    expr =
      let
        resolved = attachments.resolve {
          ctx = {
            provider = "github_actions";
          };
          userPlan = attachments.plan {
            caches = [
              {
                id = "user-cache";
                providers.github_actions = {
                  uses = "example/x@v1";
                  slot = "pre-command";
                };
              }
            ];
          };
        };
      in
      map (a: a.id) resolved.caches;
    expected = [ "user-cache" ];
  };

  testAttachmentsUnknownSlotThrows = {
    expr = builtins.tryEval (attachments.assertSlot "pre-build");
    expected = {
      success = false;
      value = false;
    };
  };

  testGhaRenderAttachmentsHelper = {
    expr =
      let
        slots = gha.renderAttachments fakePlan {
          language = "rust";
        };
      in
      {
        preHasCache = contains ''"fake-cache"'' slots.pre-command;
        postHasCov = contains "secrets.CODECOV_TOKEN" slots.post-command;
        alwaysHasReport = contains ''"fake-report"'' slots.always;
        preToolchainEmpty = slots.pre-toolchain == "";
      };
    expected = {
      preHasCache = true;
      postHasCov = true;
      alwaysHasReport = true;
      preToolchainEmpty = true;
    };
  };
}
