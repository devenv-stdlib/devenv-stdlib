# Pure helpers for tool-declared devenv tasks + preset composition.
{ lib, ... }:
let
  tasks = import ../../../stdlib/tasks.nix { inherit lib; };
  toolLib = import ../../../stdlib/tool.nix { inherit lib; };
  load = import ../../../stdlib/load.nix { inherit lib; };
  mock = import ../../lib/mock-framework.nix { inherit lib; };
  discovered = toolLib.specs (load.discover [ mock.tools ]);
  mockThrowSpec = name: {
    inherit name;
    category = "shell";
    install.kind = "project";
    upgrade = "none";
    project = { };
    tasks = _: throw "tasks evaluated";
  };
in
{
  testTaskIdQualifiesLeaf = {
    expr = tasks.taskId "mr-boxington" "gc";
    expected = "mr-boxington:gc";
  };

  testLowerQualifiesAndResolvesFunction = {
    expr = tasks.lower {
      name = "mbx";
      moduleArgs = {
        pkgs = {
          hello = "hello-bin";
        };
      };
      tasks =
        { pkgs, ... }:
        {
          gc = {
            exec = "${pkgs.hello} gc";
          };
        };
    };
    expected = {
      "mbx:gc" = {
        exec = "hello-bin gc";
      };
    };
  };

  testLowerSelectsOnlyLeaves = {
    expr = builtins.attrNames (
      tasks.lower {
        name = "mbx";
        only = [ "doctor" ];
        tasks = {
          gc = {
            exec = "gc";
          };
          doctor = {
            exec = "doctor";
          };
        };
      }
    );
    expected = [ "mbx:doctor" ];
  };

  testComposeBeforeAfterEdges = {
    expr = tasks.compose {
      around = "rust:build";
      before = [ "mr-boxington:doctor" ];
      after = [
        "mr-boxington:gc"
        "mr-boxington:stats"
      ];
    };
    expected = {
      "mr-boxington:doctor".before = [ "rust:build" ];
      "mr-boxington:gc".after = [ "rust:build" ];
      "mr-boxington:stats".after = [ "rust:build" ];
    };
  };

  testComposeAcceptsTaskRefs = {
    expr = tasks.compose {
      around = tasks.mkTaskRef "demo" "build";
      before = [ (tasks.mkTaskRef "mock-cpu" "sample") ];
      after = [ (tasks.mkTaskRef "mock-cpu" "report") ];
    };
    expected = {
      "mock-cpu:sample".before = [ "demo:build" ];
      "mock-cpu:report".after = [ "demo:build" ];
    };
  };

  # Separate workflow entries for the same satellite must keep every anchor.
  testWorkflowsMergesEdgesAcrossEntries = {
    expr = tasks.workflows [
      {
        around = "rust:build";
        before = [ "mr-boxington:doctor" ];
        after = [ "mr-boxington:gc" ];
      }
      {
        around = "rust:test";
        before = [ "mr-boxington:doctor" ];
        after = [ "mr-boxington:gc" ];
      }
    ];
    expected = {
      "mr-boxington:doctor".before = [
        "rust:build"
        "rust:test"
      ];
      "mr-boxington:gc".after = [
        "rust:build"
        "rust:test"
      ];
    };
  };

  # Exported task bodies keep their edges when composed edges are merged in.
  testMergeEdgesPreservesExportedOrdering = {
    expr = tasks.mergeEdges [
      {
        "mr-boxington:doctor" = {
          exec = "doctor";
          before = [ "enterShell" ];
        };
        "mr-boxington:gc" = {
          exec = "gc";
        };
      }
      {
        "mr-boxington:doctor".before = [ "rust:build" ];
        "mr-boxington:gc".after = [ "rust:build" ];
      }
    ];
    expected = {
      "mr-boxington:doctor" = {
        exec = "doctor";
        before = [
          "enterShell"
          "rust:build"
        ];
      };
      "mr-boxington:gc" = {
        exec = "gc";
        after = [ "rust:build" ];
      };
    };
  };

  # Non-ordering attrs still last-wins (same as recursiveUpdate / zip last).
  testMergeEdgesLastWinsNonOrdering = {
    expr = tasks.mergeEdges [
      {
        "t:a" = {
          exec = "old";
          description = "keep-me-if-only-left";
        };
      }
      {
        "t:a" = {
          exec = "new";
        };
      }
    ];
    expected = {
      "t:a" = {
        exec = "new";
        description = "keep-me-if-only-left";
      };
    };
  };

  testMockCpuDeclaresTasks = {
    expr =
      let
        hit = lib.findFirst (d: d.spec.name == "mock-cpu") null discovered;
      in
      builtins.attrNames (hit.spec.tasks or { });
    expected = [
      "report"
      "sample"
    ];
  };

  testExportMockCpuTasks = {
    expr = tasks.export {
      items = [ "mock-cpu" ];
      inherit discovered;
      moduleArgs = { };
    };
    expected = {
      "mock-cpu:sample" = {
        exec = "echo mock-cpu-sample";
      };
      "mock-cpu:report" = {
        exec = "echo mock-cpu-report";
      };
    };
  };

  # tool-ref from refsFromSpecs carries tasks; export works with discovered = [].
  testExportToolRefWithoutDiscoveredRoots = {
    expr =
      let
        refs = toolLib.refsFromSpecs discovered;
      in
      tasks.export {
        items = [ refs.profilers.cpu.mock-cpu ];
        discovered = [ ];
        moduleArgs = { };
      };
    expected = {
      "mock-cpu:sample" = {
        exec = "echo mock-cpu-sample";
      };
      "mock-cpu:report" = {
        exec = "echo mock-cpu-report";
      };
    };
  };

  testRefsFromSpecs = {
    expr =
      let
        refs = tasks.refsFromSpecs discovered { };
      in
      refs.mock-cpu.sample.id;
    expected = "mock-cpu:sample";
  };

  # A function-valued declaration is resolved before leaf names are listed.
  testRefsFromSpecsResolvesFunction = {
    expr =
      let
        refs = tasks.refsFromSpecs [
          {
            spec = {
              name = "mbx";
              tasks =
                { pkgs, ... }:
                {
                  gc.exec = pkgs.hello;
                };
            };
          }
        ] { pkgs.hello = "hello-bin"; };
      in
      refs.mbx.gc.id;
    expected = "mbx:gc";
  };

  # Lowering must not run until the host declares options.tasks. A declaration
  # that reads that option would throw on hosts that omit it.
  testApplyLocalSkipsTaskLowerWithoutHostTasks = {
    expr =
      let
        spec = {
          name = "mock-fn";
          category = "shell";
          install.kind = "project";
          upgrade = "none";
          project = { };
          tasks =
            moduleArgs:
            if (moduleArgs.options or { }) ? tasks then
              {
                leaf.exec = "ok";
              }
            else
              throw "tasks option missing";
        };
        mod = toolLib.applyLocal {
          config.tools.mock-fn.enable = true;
          options = { };
          inherit lib;
          pkgs = { };
        } spec;
      in
      (builtins.tryEval (lib.evalModules { modules = [ mod ]; })).success;
    expected = true;
  };

  # A disabled tool's task declaration must not be evaluated.
  testApplyLocalDisabledToolSkipsTasks = {
    expr =
      let
        mod = toolLib.applyLocal {
          config.tools.mock-throw.enable = false;
          options.tasks = { };
          inherit lib;
          pkgs = { };
        } (mockThrowSpec "mock-throw");
        cfg =
          (lib.evalModules {
            modules = [
              {
                options.tasks = lib.mkOption {
                  type = lib.types.attrsOf lib.types.anything;
                  default = { };
                };
                options.assertions = lib.mkOption {
                  type = lib.types.listOf lib.types.anything;
                  default = [ ];
                };
              }
              mod
            ];
          }).config;
      in
      builtins.tryEval (builtins.deepSeq cfg.tasks cfg.tasks);
    expected = {
      success = true;
      value = { };
    };
  };
}
