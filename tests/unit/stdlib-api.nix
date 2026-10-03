# Snapshot of the stdlib export. Additive: existing suites keep their imports.
{
  lib,
  ...
}:
let
  stdlib = import ../../stdlib { inherit lib; };
  oldProject = import ../../modules/lib/project.nix { inherit lib; };
  oldVersions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  oldTerminal = import ../../home/terminal-lib.nix { inherit lib; };
  oldDebtmap = import ../../modules/debtmap/lib.nix { inherit lib; };
  oldCatalog = import ../../modules/non-nix/lib.nix { inherit lib; };

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
    ++ names "harness" stdlib.harness
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
      "categories.tree"
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
      "discover"
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
      "mkTool"
      "project"
      "project.alwaysOnHookNames"
      "project.debtmapFiles"
      "project.debtmapLanguages"
      "project.javascriptOn"
      "project.langOn"
      "project.languageHooks"
      "project.serenaAlwaysLanguageServers"
      "project.serenaLanguageServers"
      "project.typescriptBundlerMissing"
      "project.typescriptBundlers"
      "project.vscodeAlwaysRecommend"
      "project.vscodeLanguageIds"
      "project.vscodeRecommendations"
      "project.vscodeUnwanted"
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
    expected = [
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
      "lang.go"
      "lang.go.linters"
      "lang.haskell"
      "lang.haskell.linters"
      "lang.javascript"
      "lang.javascript.linters"
      "lang.nix"
      "lang.nix.linters"
      "lang.python"
      "lang.python.linters"
      "lang.rust"
      "lang.rust.linters"
      "lang.typescript"
      "lang.typescript.linters"
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
  };

  testStdlibCategoryCardinality = {
    expr = builtins.listToAttrs (
      map (path: {
        name = path;
        value = cardinalityOf path;
      }) stdlib.categories.paths
    );
    expected = {
      "ai-gateways" = "zero-or-one";
      "cache" = "bundle";
      "containers" = "bundle";
      "data" = "bundle";
      "debuggers" = "any-of";
      "docs" = "bundle";
      "harness" = "exactly-one";
      "http" = "bundle";
      "ide" = "any-of";
      "infra" = "bundle";
      "infra.cloud" = "bundle";
      "infra.iac" = "exactly-one";
      "infra.kubernetes" = "bundle";
      "infra.kubernetes.cluster" = "zero-or-one";
      "lang" = "bundle";
      "lang.go" = "bundle";
      "lang.go.linters" = "bundle";
      "lang.haskell" = "bundle";
      "lang.haskell.linters" = "bundle";
      "lang.javascript" = "bundle";
      "lang.javascript.linters" = "bundle";
      "lang.nix" = "bundle";
      "lang.nix.linters" = "bundle";
      "lang.python" = "bundle";
      "lang.python.linters" = "bundle";
      "lang.rust" = "bundle";
      "lang.rust.linters" = "bundle";
      "lang.typescript" = "bundle";
      "lang.typescript.linters" = "bundle";
      "linters" = "bundle";
      "mcp" = "any-of";
      "mcp.code" = "any-of";
      "mcp.docs" = "any-of";
      "mcp.git" = "any-of";
      "mcp.web" = "any-of";
      "monitor" = "bundle";
      "profilers" = "bundle";
      "profilers.cpu" = "bundle";
      "profilers.memory" = "bundle";
      "release" = "bundle";
      "release.changelog" = "zero-or-one";
      "scanners" = "bundle";
      "secrets" = "bundle";
      "shell" = "bundle";
      "shell.history" = "zero-or-one";
      "shell.nav" = "bundle";
      "shell.prompt" = "zero-or-one";
      "tasks" = "bundle";
      "terminal" = "exactly-one";
      "terminal.mux" = "zero-or-one";
      "tui" = "bundle";
      "vcs" = "bundle";
    };
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
      cardinality = stdlib.harness.cardinality;
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
      secretEnv =
        (stdlib.harness.payloads {
          name = "demo";
          secretEnv = [ "OPENAI_API_KEY" ];
        }).homeManager.secretEnv;
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
      devenv = stdlib.devenv.load [ ];
    };
    expected = {
      den = [ ];
      devenv = [ ];
    };
  };

  testStdlibDiscoverSkipsUnderscore = {
    expr = map builtins.baseNameOf (stdlib.discover [ ../fixtures/stdlib-discover ]);
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
    expr = firstQuoted ../../home/ides/ext-lib.nix "sha256";
    expected = firstQuoted ../../stdlib/ide-ext.nix "defaultDevenvExtensionSha256";
  };
}
