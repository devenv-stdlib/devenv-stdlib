# Real Aletheore CI preset: owns aletheore.yml sync + marker surface.
{ lib, ... }:
let
  devenvLoad = import <devenv4monorepo/stdlib/devenv.nix> { inherit lib; };
  presetRoot = <devenv4monorepo/presets>;
  toolsRoot = <devenv4monorepo/tools>;
  inherit
    (import <devenv4monorepo/presets/ci/github_actions/aletheore/_workflow-text.nix> {
      inherit lib;
    })
    workflowText
    ;

  freeform = lib.types.submodule {
    freeformType = lib.types.lazyAttrsOf lib.types.anything;
  };

  eval =
    extra:
    (lib.evalModules {
      modules = [
        {
          _module.args.pkgs = {
            writeText = name: text: {
              inherit name text;
              outPath = "/tmp/${name}";
            };
            # tools.scanners.aletheore project payload (mise wrapper + install task).
            writeShellScriptBin = name: text: {
              inherit name text;
              outPath = "/tmp/${name}";
              meta.mainProgram = name;
            };
            # libstdc++ for the Aletheore CLI wrapper (numpy wheels).
            stdenv = {
              hostPlatform.isLinux = true;
              cc.cc.lib.outPath = "/tmp/libstdcxx";
            };
            # Shape enough for lib.getExe (derivation + mainProgram).
            mise = {
              type = "derivation";
              outPath = "/tmp/mise";
              outputName = "out";
              name = "mise";
              meta.mainProgram = "mise";
            };
            uv = {
              outPath = "/tmp/uv";
              meta.mainProgram = "uv";
            };
            curl = {
              outPath = "/tmp/curl";
              meta.mainProgram = "curl";
            };
            coreutils = {
              outPath = "/tmp/coreutils";
              meta.mainProgram = "coreutils";
            };
          };
        }
        {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              default = "fixture";
            };
            languages = lib.mkOption {
              type = freeform;
              default = { };
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
            };
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
            };
            warnings = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            enterShell = lib.mkOption {
              type = lib.types.lines;
              default = "";
            };
            git-hooks.hooks = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
            };
            # Real language formatters set treefmt.config; stub so owner-suite
            # evals that load tools/ without devenv's treefmt module type-check.
            treefmt = lib.mkOption {
              type = freeform;
              default = { };
            };
            files = lib.mkOption {
              type = lib.types.attrsOf freeform;
              default = { };
            };
            scripts = lib.mkOption {
              type = lib.types.attrsOf freeform;
              default = { };
            };
            # Aletheore CLI leaf adds aletheore:install when tasks exist.
            tasks = lib.mkOption {
              type = freeform;
              default = { };
            };
          };
          config = extra;
        }
      ]
      ++ devenvLoad.load {
        presets = devenvLoad.defaultRoots presetRoot;
        tools = [ toolsRoot ];
      };
    }).config;

  contains = needle: haystack: lib.hasInfix needle haystack;

  on.presets.ci.github_actions.aletheore.enable = true;

  defaultCfg = {
    action = "Aletheore/Aletheore@24f816e9297f87853b09fe514081863dc6604d30";
    actionComment = "v0.9.22";
    failOnNewSecrets = true;
    failOnNewVulnerabilities = false;
    failOnNewLayerViolations = false;
    full = false;
    postPrComment = true;
    extraWith = { };
  };
in
{
  testCiAletheorePresetOwnsWorkflow = {
    expr =
      let
        cfg = eval on;
        marker = cfg.stdlib.markers.aletheore or { };
        sync = cfg.scripts.sync-aletheore-workflow.exec or "";
        includeTools = cfg.presets.ci.github_actions.aletheore.result.includeTools or [ ];
      in
      {
        applied = cfg.presets.ci.github_actions.aletheore.result.applied or false;
        hasMarker = cfg.stdlib.markers ? aletheore;
        action = marker.action or "";
        actionComment = marker.actionComment or "";
        workflow = marker.workflow or "";
        failOnNewSecrets = marker.failOnNewSecrets or false;
        failOnNewVulnerabilities = marker.failOnNewVulnerabilities or true;
        postPrComment = marker.postPrComment or false;
        hasSync = cfg.scripts ? sync-aletheore-workflow;
        syncCopiesAletheore = contains "aletheore.yml" sync;
        hasUpdateTask = cfg.tasks ? "ci:update-aletheore";
        enterWritesWorkflow = contains "sync-aletheore-workflow" cfg.enterShell;
        generatedPath =
          (lib.findFirst (g: g.path == ".github/workflows/aletheore.yml") null cfg.stdlib.generated) != null;
        # Preset enables the local Aletheore CLI catalog leaf.
        inherit includeTools;
        toolEnable = (cfg.tools.aletheore or { }).enable or false;
        hasAletheorePackage = lib.any (p: (p.name or "") == "aletheore") cfg.packages;
        hasInstallTask = cfg.tasks ? "aletheore:install";
        # Wrapper prefixes nixpkgs libstdc++ for pipx/uv numpy wheels.
        wrapperExportsLibstdcxx =
          let
            pkg = lib.findFirst (p: (p.name or "") == "aletheore") null cfg.packages;
          in
          pkg != null
          && contains "LD_LIBRARY_PATH=" (pkg.text or "")
          && contains "/tmp/libstdcxx" (pkg.text or "");
      };
    expected = {
      applied = true;
      hasMarker = true;
      action = "Aletheore/Aletheore@24f816e9297f87853b09fe514081863dc6604d30";
      actionComment = "v0.9.22";
      workflow = "aletheore.yml";
      failOnNewSecrets = true;
      failOnNewVulnerabilities = false;
      postPrComment = true;
      hasSync = true;
      syncCopiesAletheore = true;
      hasUpdateTask = true;
      enterWritesWorkflow = false;
      generatedPath = true;
      includeTools = [ "aletheore" ];
      toolEnable = true;
      hasAletheorePackage = true;
      hasInstallTask = true;
      wrapperExportsLibstdcxx = true;
    };
  };

  testCiAletheoreDefaultOffRemovesWriter = {
    expr =
      let
        cfg = eval on;
        disabled = eval { };
      in
      {
        enabledApplied = cfg.presets.ci.github_actions.aletheore.result.applied or false;
        disabledApplied = disabled.presets.ci.github_actions.aletheore.result.applied or false;
        disabledHasMarker = disabled.stdlib.markers ? aletheore;
        disabledHasSync = disabled.scripts ? sync-aletheore-workflow;
        actionOption = cfg.presets.ci.github_actions.aletheore.action;
        actionCommentOption = cfg.presets.ci.github_actions.aletheore.actionComment;
        failOnNewSecretsOption = cfg.presets.ci.github_actions.aletheore.failOnNewSecrets;
        disabledToolEnable = (disabled.tools.aletheore or { }).enable or false;
        disabledHasPackage = lib.any (p: (p.name or "") == "aletheore") disabled.packages;
        disabledHasInstallTask = disabled.tasks ? "aletheore:install";
      };
    expected = {
      enabledApplied = true;
      disabledApplied = false;
      disabledHasMarker = false;
      disabledHasSync = false;
      actionOption = "Aletheore/Aletheore@24f816e9297f87853b09fe514081863dc6604d30";
      actionCommentOption = "v0.9.22";
      failOnNewSecretsOption = true;
      disabledToolEnable = false;
      disabledHasPackage = false;
      disabledHasInstallTask = false;
    };
  };

  testCiAletheoreWorkflowTextDefaults = {
    expr =
      let
        yaml = workflowText defaultCfg;
      in
      {
        hasName = contains "name: Aletheore" yaml;
        hasJobName = contains "name: Security review (Aletheore)" yaml;
        hasPullRequest = contains "pull_request:" yaml;
        lacksTarget = contains "pull_request_target" yaml;
        hasAction = contains "Aletheore/Aletheore@24f816e9297f87853b09fe514081863dc6604d30" yaml;
        hasActionComment = contains "# v0.9.22" yaml;
        hasFailSecrets = contains "fail-on-new-secrets: true" yaml;
        hasFailVulns = contains "fail-on-new-vulnerabilities: false" yaml;
        hasFailLayers = contains "fail-on-new-layer-violations: false" yaml;
        # Same-repo gate (fork PRs have a read-only GITHUB_TOKEN).
        hasPostGate = contains "post-pr-comment: \${{ github.event.pull_request.head.repo.full_name == github.repository }}" yaml;
        lacksLiteralPostTrue = contains "post-pr-comment: true" yaml;
        hasIssuesWrite = contains "issues: write" yaml;
        hasPrWrite = contains "pull-requests: write" yaml;
        hasRunner = contains "runs-on: ubuntu-24.04" yaml;
        # Action checkouts base/head itself — host workflow has no checkout step.
        hasCheckout = contains "actions/checkout" yaml;
      };
    expected = {
      hasName = true;
      hasJobName = true;
      hasPullRequest = true;
      lacksTarget = false;
      hasAction = true;
      hasActionComment = true;
      hasFailSecrets = true;
      hasFailVulns = true;
      hasFailLayers = true;
      hasPostGate = true;
      lacksLiteralPostTrue = false;
      hasIssuesWrite = true;
      hasPrWrite = true;
      hasRunner = true;
      hasCheckout = false;
    };
  };

  testCiAletheoreExtraWithOverrides = {
    expr =
      let
        yaml = workflowText (
          defaultCfg
          // {
            failOnNewSecrets = false;
            failOnNewVulnerabilities = true;
            extraWith = {
              full = "true";
              fail-on-new-secrets = "true";
            };
          }
        );
        cfg = eval {
          presets.ci.github_actions.aletheore = {
            enable = true;
            failOnNewSecrets = false;
            failOnNewVulnerabilities = true;
            extraWith = {
              full = "true";
              fail-on-new-secrets = "true";
            };
          };
        };
        marker = cfg.stdlib.markers.aletheore;
      in
      {
        inherit (marker) failOnNewSecrets failOnNewVulnerabilities;
        yamlHasFull = contains "full: true" yaml;
        # extraWith overrides the named fail-on-new-secrets scalar in YAML.
        yamlHasSecretsTrue = contains "fail-on-new-secrets: true" yaml;
        yamlLacksSecretsFalse = contains "fail-on-new-secrets: false" yaml;
        hasSync = cfg.scripts ? sync-aletheore-workflow;
      };
    expected = {
      failOnNewSecrets = false;
      failOnNewVulnerabilities = true;
      yamlHasFull = true;
      yamlHasSecretsTrue = true;
      yamlLacksSecretsFalse = false;
      hasSync = true;
    };
  };
}
