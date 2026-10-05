# Integration catalog: MatrixPlan shapes rendered through the GHA backend.
# Host-side asserts (eval.nix / nixosTest) plus YAML fixtures (workflows.nix / actionlint).
{ lib }:
let
  inherit (import ../../stdlib { inherit lib; }) ci;
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  inherit (ci) matrix;
  gha = ci.backends.github_actions;
  contains = needle: hay: lib.hasInfix needle hay;
  profiles = matrix.defaultRunnerProfiles;

  includeCount =
    yaml: lib.length (lib.filter (l: lib.hasPrefix "          - os:" l) (lib.splitString "\n" yaml));

  missingNeedles = yaml: needles: lib.filter (n: !(contains n yaml)) needles;

  unexpectedNeedles = yaml: needles: lib.filter (n: contains n yaml) needles;

  cellRows =
    plan: jobName:
    let
      job = plan.jobs.${jobName};
      cells = job.cells or [ ];
      jobOptional = job.optional or false;
      anyCellOptional = lib.any (c: c.optional or false) cells;
      keepOptional = !jobOptional && anyCellOptional;
    in
    map (cell: gha.matrixRow (gha.rowAttrs plan cell { inherit keepOptional; })) cells;

  missingRows = yaml: rows: lib.filter (r: !(contains (gha.padJob r) yaml)) rows;

  cartesianPlan = matrix.plan {
    runnerProfiles = profiles;
    jobs.cartesian = {
      command = "true";
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
  };
  cartesianYaml = gha.render cartesianPlan;

  explicitPlan = matrix.plan {
    runnerProfiles = profiles;
    jobs.explicit = {
      command = "true";
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
  };
  explicitYaml = gha.render explicitPlan;

  filteredPlan = matrix.plan {
    runnerProfiles = profiles;
    jobs.filtered = {
      command = "true";
      dimensions = {
        runner = [
          "ubuntu-lts-prev"
          "ubuntu-lts-curr"
        ];
      };
      seeds = [
        { toolchain = "3.12"; }
        { toolchain = "3.13"; }
      ];
      exclude = [
        {
          runner = "ubuntu-lts-prev";
          toolchain = "3.13";
        }
      ];
      include = [
        {
          runner = "ubuntu-lts-curr";
          toolchain = "nightly";
        }
      ];
    };
  };
  filteredYaml = gha.render filteredPlan;

  mixedPlan = matrix.plan {
    runnerProfiles = profiles;
    jobs.mixed = {
      command = "true";
      dimensions.runner = [ "ubuntu-lts-prev" ];
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
  mixedYaml = gha.render mixedPlan;

  quotedPlan = matrix.plan {
    runnerProfiles = profiles;
    jobs.quoted = {
      command = "true";
      dimensions.runner = [ "ubuntu-lts-prev" ];
      seeds = [ { version = ''3.12"beta''; } ];
    };
  };
  quotedYaml = gha.render quotedPlan;

  multilinePlan = matrix.plan {
    runnerProfiles = profiles;
    jobs.multiline = {
      command = "echo one\necho two";
      dimensions.runner = [ "ubuntu-lts-prev" ];
      seeds = [ { version = "1"; } ];
    };
  };
  multilineYaml = gha.render multilinePlan;

  jobOptPlan = matrix.plan {
    runnerProfiles = profiles;
    jobs.jobopt = {
      optional = true;
      command = "true";
      dimensions.runner = [ "ubuntu-lts-prev" ];
      seeds = [ { version = "1"; } ];
    };
  };
  jobOptYaml = gha.render jobOptPlan;

  parallelPlan = matrix.plan {
    runnerProfiles = profiles;
    jobs.parallel = {
      command = "true";
      strategy.maxParallel = 2;
      dimensions = {
        runner = [
          "ubuntu-lts-prev"
          "ubuntu-lts-curr"
        ];
      };
      seeds = [ { version = "1"; } ];
    };
  };
  parallelYaml = gha.render parallelPlan;

  gpuPlan = matrix.plan {
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
  gpuYaml = gha.render gpuPlan;

  emptyDefaultYaml = gha.render (
    matrix.plan {
      runnerProfiles = profiles;
      jobs = { };
    }
  );

  emptyTruePlan = matrix.plan {
    runnerProfiles.boolish = {
      os = "linux";
      arch = "x86_64";
      providers.github_actions.runs-on = [ "true" ];
    };
    jobs = { };
  };
  emptyTrueYaml = gha.emptyWorkflow emptyTruePlan;

  emptyMultiPlan = matrix.plan {
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
      inherit (profiles) ubuntu-lts-prev;
    };
    jobs = { };
  };
  emptyMultiYaml = gha.emptyWorkflow emptyMultiPlan;

  languagePythonYaml = versions.workflowText {
    pythonOn = true;
    python = versions.emptyPython // {
      min = "3.12";
      max = "3.13";
    };
  };

  shape =
    {
      yaml,
      problems,
      actionlint ? true,
    }:
    {
      inherit yaml actionlint;
      problems = lib.filter (p: p != null) problems;
    };

  shapes = {
    cartesian = shape {
      yaml = cartesianYaml;
      problems = [
        (if includeCount cartesianYaml == 4 then null else "cartesian: expected 4 include rows")
        (if lib.length cartesianPlan.jobs.cartesian.cells == 4 then null else "cartesian: cell count")
      ]
      ++ map (n: "cartesian missing ${n}") (
        missingNeedles cartesianYaml [
          "workflow_call:"
          "cartesian:"
          ''os: "ubuntu-24.04"''
          ''os: "ubuntu-26.04"''
          ''toolchain: "3.12"''
          ''toolchain: "3.13"''
        ]
      )
      ++ map (n: "cartesian unexpected ${n}") (
        unexpectedNeedles cartesianYaml [
          "optional:"
          "no-language-matrix:"
        ]
      )
      ++ (
        if missingRows cartesianYaml (cellRows cartesianPlan "cartesian") == [ ] then
          [ ]
        else
          [ "cartesian missing row" ]
      );
    };

    explicit = shape {
      yaml = explicitYaml;
      problems = [
        (if includeCount explicitYaml == 2 then null else "explicit: expected 2 include rows")
        (if lib.length explicitPlan.jobs.explicit.cells == 2 then null else "explicit: cell count")
      ]
      ++ map (n: "explicit missing ${n}") (
        missingNeedles explicitYaml [
          "explicit:"
          ''os: "ubuntu-24.04"''
          ''os: "ubuntu-26.04"''
          ''toolchain: "3.12"''
          ''toolchain: "3.13"''
        ]
      )
      ++ (
        if missingRows explicitYaml (cellRows explicitPlan "explicit") == [ ] then
          [ ]
        else
          [ "explicit missing row" ]
      );
    };

    filtered = shape {
      yaml = filteredYaml;
      problems = [
        (if includeCount filteredYaml == 4 then null else "filtered: expected 4 include rows")
        (if lib.length filteredPlan.jobs.filtered.cells == 4 then null else "filtered: cell count")
      ]
      ++ map (n: "filtered missing ${n}") (
        missingNeedles filteredYaml [
          "filtered:"
          ''toolchain: "nightly"''
        ]
      )
      ++ (
        if missingRows filteredYaml (cellRows filteredPlan "filtered") == [ ] then
          [ ]
        else
          [ "filtered missing row" ]
      )
      ++ (
        let
          dropped = gha.padJob (
            gha.matrixRow (
              gha.rowAttrs filteredPlan {
                runner = "ubuntu-lts-prev";
                toolchain = "3.13";
                optional = false;
              } { }
            )
          );
        in
        if contains dropped filteredYaml then [ "filtered: excluded prev×3.13 still rendered" ] else [ ]
      );
    };

    mixed-optional = shape {
      yaml = mixedYaml;
      problems = [
        (
          if
            contains "    runs-on: \${{ matrix.os }}\n    continue-on-error: \${{ matrix.optional }}\n    strategy:" mixedYaml
          then
            null
          else
            "mixed-optional: continue-on-error not a sibling of runs-on"
        )
        (
          if contains "continue-on-error: true\n" mixedYaml then
            "mixed-optional: job-level continue-on-error: true"
          else
            null
        )
      ]
      ++ map (n: "mixed-optional missing ${n}") (
        missingNeedles mixedYaml [
          "optional: true"
          "optional: false"
        ]
      )
      ++ (
        if missingRows mixedYaml (cellRows mixedPlan "mixed") == [ ] then
          [ ]
        else
          [ "mixed-optional missing row" ]
      );
    };

    quoted-scalar = shape {
      yaml = quotedYaml;
      problems = [
        (if contains ''version: "3.12\"beta"'' quotedYaml then null else "quoted-scalar: escaped version")
        (if contains ''version: "3.12"beta"'' quotedYaml then "quoted-scalar: broken quote form" else null)
      ];
    };

    multiline-command = shape {
      yaml = multilineYaml;
      problems = [
        (
          if
            contains "name: Test\n        run: |\n                echo one\n                echo two" multilineYaml
          then
            null
          else
            "multiline-command: block scalar"
        )
        (
          if contains "name: Test\n        run: echo one\necho two" multilineYaml then
            "multiline-command: inline multiline"
          else
            null
        )
      ];
    };

    job-optional = shape {
      yaml = jobOptYaml;
      problems = [
        (
          if
            contains "    runs-on: \${{ matrix.os }}\n    continue-on-error: true\n    strategy:" jobOptYaml
          then
            null
          else
            "job-optional: continue-on-error not a sibling of runs-on"
        )
        (if contains "matrix.optional" jobOptYaml then "job-optional: unexpected matrix.optional" else null)
        (if contains "optional:" jobOptYaml then "job-optional: optional leaked into include" else null)
      ];
    };

    max-parallel = shape {
      yaml = parallelYaml;
      problems = [
        (
          if contains "      fail-fast: false\n      max-parallel: 2\n      matrix:" parallelYaml then
            null
          else
            "max-parallel: max-parallel not a sibling of fail-fast"
        )
        (if includeCount parallelYaml == 2 then null else "max-parallel: expected 2 include rows")
      ];
    };

    language-python = shape {
      yaml = languagePythonYaml;
      problems =
        map (n: "language-python missing ${n}") (
          missingNeedles languagePythonYaml [
            "python:"
            "workflow_call:"
            ''os: "ubuntu-24.04"''
            "3.12"
            "supported.python.min"
          ]
        )
        ++ map (n: "language-python unexpected ${n}") (
          unexpectedNeedles languagePythonYaml [
            "optional:"
            "no-language-matrix:"
            ''os: ["ubuntu-24.04"]''
          ]
        );
    };

    empty-default = shape {
      yaml = emptyDefaultYaml;
      problems =
        map (n: "empty-default missing ${n}") (
          missingNeedles emptyDefaultYaml [
            "no-language-matrix:"
            "workflow_call:"
            ''os: ["ubuntu-24.04", "ubuntu-26.04"]''
          ]
        )
        ++ map (n: "empty-default unexpected ${n}") (
          unexpectedNeedles emptyDefaultYaml [
            "include:"
            "python:"
          ]
        );
    };

    empty-true-label = shape {
      actionlint = false;
      yaml = emptyTrueYaml;
      problems = [
        (if contains ''os: ["true"]'' emptyTrueYaml then null else "empty-true-label: expected quoted true")
        (if contains "os: [true]" emptyTrueYaml then "empty-true-label: unquoted YAML bool" else null)
      ];
    };

    multi-label = shape {
      actionlint = false;
      yaml = gpuYaml;
      problems =
        map (n: "multi-label missing ${n}") (
          missingNeedles gpuYaml [
            ''os: ["self-hosted", "linux", "x64", "gpu"]''
            "gpu:"
          ]
        )
        ++ map (n: "multi-label unexpected ${n}") (
          unexpectedNeedles gpuYaml [
            ''os: "self-hosted"''
          ]
        );
    };

    empty-multi-label = shape {
      actionlint = false;
      yaml = emptyMultiYaml;
      problems =
        map (n: "empty-multi-label missing ${n}") (
          missingNeedles emptyMultiYaml [
            "include:"
            ''os: ["self-hosted", "linux", "gpu"]''
            ''os: "ubuntu-24.04"''
          ]
        )
        ++ map (n: "empty-multi-label unexpected ${n}") (
          unexpectedNeedles emptyMultiYaml [
            ''os: "self-hosted"''
          ]
        );
    };
  };

  problems = lib.concatLists (lib.mapAttrsToList (_: s: s.problems) shapes);
  fixtures = lib.mapAttrs (_: s: s.yaml) shapes;
  actionlintNames = lib.filter (n: shapes.${n}.actionlint) (lib.attrNames shapes);
in
if problems != [ ] then
  throw "matrix-shapes: ${lib.concatStringsSep "; " problems}"
else
  {
    ok = true;
    inherit
      fixtures
      shapes
      actionlintNames
      ;
    names = lib.attrNames shapes;
  }
