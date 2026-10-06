# Snapshot of the stdlib export. Additive: existing suites keep their imports.
{
  lib,
  ...
}:
let
  stdlib = import ../../../stdlib { inherit lib; };
  oldProject = import ../../../modules/lib/project.nix { inherit lib; };
  oldVersions = import ../../../modules/languages/versions-lib.nix { inherit lib; };
  oldTerminal = import ../../../home/terminal-lib.nix { inherit lib; };
  oldDebtmap = import ../../../modules/debtmap/lib.nix { inherit lib; };
  oldCatalog = import ../../../modules/non-nix/lib.nix { inherit lib; };

  sort = lib.sort (a: b: a < b);

  names =
    prefix: set:
    map (name: if prefix == "" then name else "${prefix}.${name}") (sort (builtins.attrNames set));

  apiPaths = sort (
    names "" stdlib
    ++ names "project" stdlib.project
    ++ names "terminal" stdlib.terminal
    ++ names "debtmap" stdlib.debtmap
    ++ names "catalog" stdlib.catalog
    ++ names "categories" stdlib.categories
    ++ names "categoryPolicy" stdlib.categoryPolicy
    ++ names "categoryWarnings" stdlib.categoryWarnings
    ++ names "harness" stdlib.harness
    ++ names "shell" stdlib.shell
    ++ names "linters" stdlib.linters
    ++ names "log" stdlib.log
    ++ names "report" stdlib.report
    ++ names "generate" stdlib.generate
    ++ names "den" stdlib.den
    ++ names "devenv" stdlib.devenv
    ++ names "versions" (stdlib.versions { })
  );

  firstQuoted =
    file: name:
    let
      lines = lib.splitString "\n" (builtins.readFile file);
      matches = builtins.filter (
        line: builtins.match "[[:space:]]*${name} = \"([^\"]+)\";.*" line != null
      ) lines;
    in
    if matches == [ ] then
      null
    else
      builtins.head (builtins.match "[[:space:]]*${name} = \"([^\"]+)\";.*" (builtins.head matches));

  cardinalityOf = path: (stdlib.categories.resolve path).cardinality;

  supported = stdlib.devenvSupported;

  expectedLangPaths = lib.concatMap (lang: [
    "lang.${lang}"
    "lang.${lang}.linters"
  ]) supported.languages;

  expectedServicePaths = map (svc: "services.${svc}") supported.services;

  # Non-lang/services category paths (stable scaffold outside devenv ids).
  expectedOtherPaths = [
    "ai-gateways"
    "cache"
    "containers"
    "data"
    "debuggers"
    "docs"
    "harness"
    "http"
    "ide"
    "infra"
    "infra.cloud"
    "infra.iac"
    "infra.kubernetes"
    "infra.kubernetes.cluster"
    "lang"
    "linters"
    "mcp"
    "mcp.code"
    "mcp.docs"
    "mcp.git"
    "mcp.web"
    "monitor"
    "profilers"
    "profilers.cpu"
    "profilers.memory"
    "release"
    "release.changelog"
    "scanners"
    "secrets"
    "services"
    "shell"
    "shell.history"
    "shell.nav"
    "shell.prompt"
    "tasks"
    "terminal"
    "terminal.mux"
    "tui"
    "vcs"
  ];

  expectedPaths = sort (expectedOtherPaths ++ expectedLangPaths ++ expectedServicePaths);

  expectedCardinality =
    builtins.listToAttrs (
      map
        (path: {
          name = path;
          value = "bundle";
        })
        (
          expectedLangPaths
          ++ expectedServicePaths
          ++ [
            "cache"
            "containers"
            "data"
            "docs"
            "http"
            "infra"
            "infra.cloud"
            "infra.kubernetes"
            "lang"
            "linters"
            "monitor"
            "profilers"
            "profilers.cpu"
            "profilers.memory"
            "release"
            "scanners"
            "secrets"
            "services"
            "shell"
            "shell.nav"
            "tasks"
            "tui"
            "vcs"
          ]
        )
    )
    // {
      "ai-gateways" = "zero-or-one";
      "debuggers" = "any-of";
      "harness" = "exactly-one";
      "ide" = "any-of";
      "infra.iac" = "exactly-one";
      "infra.kubernetes.cluster" = "zero-or-one";
      "mcp" = "any-of";
      "mcp.code" = "any-of";
      "mcp.docs" = "any-of";
      "mcp.git" = "any-of";
      "mcp.web" = "any-of";
      "release.changelog" = "zero-or-one";
      "shell.history" = "zero-or-one";
      "shell.prompt" = "zero-or-one";
      "terminal" = "exactly-one";
      "terminal.mux" = "zero-or-one";
    };
in
{
  testStdlibVersion = {
    expr = stdlib.version;
    expected = "0.1.0";
  };

  testStdlibApiVersion = {
    expr = stdlib.apiVersion;
    expected = "0";
  };

  testStdlibApiPaths = {
    expr = apiPaths;
    expected = [
      "apiVersion"
      "binary"
      "catalog"
      "catalog.binName"
      "catalog.catalog"
      "catalog.catalogFile"
      "catalog.dockerImages"
      "catalog.entryByName"
      "catalog.filterScope"
      "catalog.imageRef"
      "catalog.local"
      "catalog.localCatalogFile"
      "catalog.miseCli"
      "catalog.nixPackages"
      "catalog.resolve"
      "catalog.resolveOne"
      "catalog.resolvedByName"
      "catalog.shipped"
      "catalog.toMiseToml"
      "categories"
      "categories.cardinalities"
      "categories.cardinalityViolation"
      "categories.paths"
      "categories.resolve"
      "categories.supported"
      "categories.tree"
      "categoryPolicy"
      "categoryPolicy.bindPreset"
      "categoryPolicy.forCategoryNode"
      "categoryPolicy.forId"
      "categoryPolicy.forPresetPath"
      "categoryPolicy.forToolCategory"
      "categoryPolicy.inheritedWhen"
      "categoryPolicy.languageAvailable"
      "categoryPolicy.mkAnyLanguagePolicy"
      "categoryPolicy.mkLanguagePolicy"
      "categoryPolicy.mkServicePolicy"
      "categoryPolicy.optionsModule"
      "categoryPolicy.policies"
      "categoryPolicy.policyIds"
      "categoryPolicy.requiresOf"
      "categoryPolicy.serviceAvailable"
      "categoryPolicy.supported"
      "categoryPolicy.toolAssertions"
      "categoryWarnings"
      "categoryWarnings.categoryHasPrefix"
      "categoryWarnings.checks"
      "categoryWarnings.mkWarning"
      "categoryWarnings.module"
      "categoryWarnings.optionsModule"
      "categoryWarnings.pathHasPrefix"
      "categoryWarnings.unusedPaths"
      "categoryWarnings.unusedWarnings"
      "debtmap"
      "debtmap.defaultGodObject"
      "debtmap.godLimitsToml"
      "debtmap.godObjectKey"
      "debtmap.ignoreFor"
      "debtmap.ignorePatterns"
      "debtmap.ignoreShared"
      "debtmap.official"
      "debtmap.sample"
      "debtmap.toToml"
      "den"
      "den.load"
      "devenv"
      "devenv.load"
      "devenvSupported"
      "discover"
      "generate"
      "generate.ensureTrailingNewline"
      "generate.mkEnsureTrailingNewlineExec"
      "generate.mkSyncFileExec"
      "harness"
      "harness.cardinality"
      "harness.category"
      "harness.configPath"
      "harness.installKinds"
      "harness.knownTools"
      "harness.multiCardinality"
      "harness.options"
      "harness.payloads"
      "harness.presetPath"
      "harness.toolPath"
      "ideExt"
      "linters"
      "linters.alwaysOn"
      "linters.alwaysOnGitHooks"
      "linters.alwaysOnPrek"
      "linters.alwaysOnTreefmt"
      "linters.catalog"
      "linters.prek"
      "linters.treefmt"
      "log"
      "log.debug"
      "log.debug'"
      "log.info"
      "log.info'"
      "log.trace"
      "log.trace'"
      "log.usingNixLog"
      "log.warn"
      "log.warn'"
      "log.warnIf"
      "mkTool"
      "project"
      "project.alwaysOnGitHookNames"
      "project.alwaysOnHookNames"
      "project.alwaysOnPrekHooks"
      "project.alwaysOnTreefmtLinters"
      "project.debtmapFiles"
      "project.debtmapLanguages"
      "project.javascriptOn"
      "project.langOn"
      "project.languageHooks"
      "project.lintersCatalog"
      "project.serenaAlwaysLanguageServers"
      "project.serenaLanguageServers"
      "project.typescriptBundlerMissing"
      "project.typescriptBundlers"
      "project.vscodeAlwaysRecommend"
      "project.vscodeLanguageIds"
      "project.vscodeRecommendations"
      "project.vscodeUnwanted"
      "report"
      "report.enabledHookNames"
      "report.enabledTreefmtPrograms"
      "report.flattenPresetLeaves"
      "report.flattenToolLeaves"
      "report.formatGenerated"
      "report.formatReport"
      "report.inventory"
      "report.logInventory"
      "report.matrixInventory"
      "report.mkEnterShellGeneratedCheck"
      "report.mkEnterShellSnippet"
      "report.mkEvalWarning"
      "report.toolsNaviHint"
      "shell"
      "shell.category"
      "shell.enableIntegrations"
      "shell.enabledShells"
      "shell.hmModule"
      "shell.knownShells"
      "shell.mkShellOption"
      "shell.policyShells"
      "shell.preferredOption"
      "shell.requireResolved"
      "shell.resolve"
      "shell.shellType"
      "shell.shouldInstallBlesh"
      "shell.soleEnabled"
      "shell.toolPath"
      "terminal"
      "terminal.desktopIds"
      "terminal.mkDesktopEntry"
      "terminal.quakeExtensionUuid"
      "terminal.toGnomeBinding"
      "terminal.warpPackage"
      "terminal.warpSettingsToml"
      "terminal.warpShortcutId"
      "terminal.warpShortcutPath"
      "version"
      "versions"
      "versions.boundProblems"
      "versions.catalogActive"
      "versions.crossOs"
      "versions.cycleLabel"
      "versions.emptyGo"
      "versions.emptyJavascript"
      "versions.emptyPolicy"
      "versions.emptyPython"
      "versions.emptyRust"
      "versions.enumerateRange"
      "versions.expandExplicit"
      "versions.findRelease"
      "versions.formatVersion"
      "versions.goRows"
      "versions.hasPatch"
      "versions.inRange"
      "versions.javascriptRows"
      "versions.jobYaml"
      "versions.jsRuntimes"
      "versions.languageJobs"
      "versions.matchesCycle"
      "versions.matrixReport"
      "versions.matrixRow"
      "versions.nodePackage"
      "versions.omitsPatch"
      "versions.padJob"
      "versions.parseVersion"
      "versions.problems"
      "versions.pythonImpls"
      "versions.pythonRows"
      "versions.rangeStepOk"
      "versions.releaseUnsupported"
      "versions.resolveFromCatalog"
      "versions.resolvedVersions"
      "versions.resolvedVersionsFor"
      "versions.rustChannels"
      "versions.rustEditionBoundProblem"
      "versions.rustEditionSince"
      "versions.rustEditionTooOld"
      "versions.rustEditions"
      "versions.rustRows"
      "versions.rustfmtEditionArgs"
      "versions.ubuntuLts"
      "versions.ubuntuRunners"
      "versions.withPolicyMin"
      "versions.workflowText"
    ];
  };

  testStdlibCategoryPaths = {
    expr = stdlib.categories.paths;
    expected = expectedPaths;
  };

  testStdlibDevenvSupportedScaffold = {
    expr = {
      nLangs = builtins.length supported.languages;
      nServices = builtins.length supported.services;
      python = (stdlib.categories.resolve "lang.python").categoryPolicy;
      zig = (stdlib.categories.resolve "lang.zig").categoryPolicy;
      postgres = (stdlib.categories.resolve "services.postgres").categoryPolicy;
      hasPythonLinters = lib.elem "lang.python.linters" stdlib.categories.paths;
      hasZigLinters = lib.elem "lang.zig.linters" stdlib.categories.paths;
    };
    expected = {
      nLangs = 58;
      nServices = 43;
      python = "python";
      zig = "zig";
      postgres = "services.postgres";
      hasPythonLinters = true;
      hasZigLinters = true;
    };
  };

  testStdlibCategoryCardinality = {
    expr = builtins.listToAttrs (
      map (path: {
        name = path;
        value = cardinalityOf path;
      }) stdlib.categories.paths
    );
    expected = expectedCardinality;
  };

  testStdlibProfilersAreSplit = {
    expr = {
      parent = (stdlib.categories.resolve "profilers").tools;
      children = builtins.attrNames (stdlib.categories.resolve "profilers").children;
      cpu = (stdlib.categories.resolve "profilers.cpu").tools;
      memory = (stdlib.categories.resolve "profilers.memory").tools;
    };
    expected = {
      parent = [ ];
      children = [
        "cpu"
        "memory"
      ];
      cpu = [
        "samply"
        "py-spy"
        "cargo-flamegraph"
        "pprof"
      ];
      memory = [
        "valgrind"
        "cargo-valgrind"
      ];
    };
  };

  testStdlibUnknownCategoryThrows = {
    expr = (builtins.tryEval (stdlib.categories.resolve "profilers.disk")).success;
    expected = false;
  };

  testStdlibExactlyOneViolation = {
    expr = stdlib.categories.cardinalityViolation (stdlib.categories.resolve "terminal") [ ];
    expected = "exactly-one node requires one enabled tool (got 0)";
  };

  testStdlibBundleAllowsEmpty = {
    expr = stdlib.categories.cardinalityViolation (stdlib.categories.resolve "profilers") [ ];
    expected = null;
  };

  testStdlibZeroOrOneViolation = {
    expr = stdlib.categories.cardinalityViolation (stdlib.categories.resolve "shell.prompt") [
      "starship"
      "other"
    ];
    expected = "zero-or-one node allows at most one enabled tool (got 2)";
  };

  testStdlibAiGatewaysShelved = {
    expr = {
      inherit (stdlib.categories.resolve "ai-gateways") tools shelved;
    };
    expected = {
      tools = [ ];
      shelved = [
        "9router"
        "litellm"
      ];
    };
  };

  testStdlibHarnessFoundations = {
    expr = {
      inherit (stdlib.harness) cardinality;
      multi = stdlib.harness.multiCardinality;
      tools = stdlib.harness.knownTools;
      install = stdlib.harness.installKinds;
      config = stdlib.harness.configPath "opencode" "config.json";
      tool = stdlib.harness.toolPath "opencode";
      preset = stdlib.harness.presetPath "opencode";
      secretDefault = (stdlib.harness.options "demo").secretEnv.default;
      inherit
        (stdlib.harness.payloads {
          name = "demo";
          secretEnv = [ "OPENAI_API_KEY" ];
        })
        project
        ;
      inherit
        ((stdlib.harness.payloads {
          name = "demo";
          secretEnv = [ "OPENAI_API_KEY" ];
        }).homeManager
        )
        secretEnv
        ;
    };
    expected = {
      cardinality = "exactly-one";
      multi = "any-of";
      tools = [
        "opencode"
        "claude-code"
        "codex"
      ];
      install = [
        "nix"
        "catalog"
        "self"
      ];
      config = ".config/opencode/config.json";
      tool = "tools/harness/opencode.nix";
      preset = "presets/harness/opencode.nix";
      secretDefault = [ ];
      project = {
        name = "demo";
      };
      secretEnv = [ "OPENAI_API_KEY" ];
    };
  };

  testStdlibHarnessRejectsSecretLiteral = {
    expr =
      (builtins.tryEval (
        stdlib.harness.payloads {
          name = "demo";
          secretEnv = [ "not-an-env" ];
        }
      )).success;
    expected = false;
  };

  testStdlibHarnessRejectsOverriddenSecretEnv = {
    expr =
      (builtins.tryEval (
        stdlib.harness.payloads {
          name = "demo";
          homeManager.secretEnv = [ "not-an-env" ];
        }
      )).success;
    expected = false;
  };

  testStdlibHarnessKeepsValidSecretOverride = {
    expr =
      (stdlib.harness.payloads {
        name = "demo";
        secretEnv = [ "OPENAI_API_KEY" ];
        homeManager.secretEnv = [ "ANTHROPIC_API_KEY" ];
      }).homeManager.secretEnv;
    expected = [ "ANTHROPIC_API_KEY" ];
  };

  testStdlibLoadersEmpty = {
    expr = {
      den = stdlib.den.load [ ./missing-tools ];
      # Empty preset/tool roots still inject always-on category-policy
      # (and later category-warnings) modules — not a fully empty list.
      devenvNonEmpty = (builtins.length (stdlib.devenv.load [ ])) >= 1;
    };
    expected = {
      den = [ ];
      devenvNonEmpty = true;
    };
  };

  testStdlibDiscoverSkipsUnderscore = {
    expr = map builtins.baseNameOf (stdlib.discover [ ../../fixtures/stdlib-discover ]);
    # fixtures/stdlib-discover/tests/not-a-tool.nix is skipped (tests/ dirs).
    expected = [ "leaf.nix" ];
  };

  testStdlibShimProject = {
    expr = oldProject.debtmapLanguages {
      rust.enable = true;
      python.enable = true;
    };
    expected = stdlib.project.debtmapLanguages {
      rust.enable = true;
      python.enable = true;
    };
  };

  testStdlibShimVersions = {
    expr = oldVersions.ubuntuLts;
    expected = (stdlib.versions { }).ubuntuLts;
  };

  testStdlibShimTerminal = {
    expr = oldTerminal.toGnomeBinding "ctrl-shift-f12";
    expected = stdlib.terminal.toGnomeBinding "ctrl-shift-f12";
  };

  testStdlibShimDebtmap = {
    expr = oldDebtmap.godObjectKey "typescript";
    expected = stdlib.debtmap.godObjectKey "typescript";
  };

  testStdlibShimCatalog = {
    expr = (oldCatalog.entryByName "navi").name;
    expected = (stdlib.catalog.entryByName "navi").name;
  };

  testStdlibDevenvExtensionHashSynced = {
    expr = firstQuoted ../../../home/ides/ext-lib.nix "sha256";
    expected = firstQuoted ../../../stdlib/ide-ext.nix "defaultDevenvExtensionSha256";
  };
}
