# Real PR Metrics CI preset: owns pr-metrics.yml sync + marker surface.
# Framework default is opt-in (enable = false); dogfood sets enable = true.
{ lib, ... }:
let
  devenvLoad = import <devenv4monorepo/stdlib/devenv.nix> { inherit lib; };
  presetRoot = <devenv4monorepo/presets>;
  toolsRoot = <devenv4monorepo/tools>;
  inherit
    (import <devenv4monorepo/presets/ci/github_actions/pr-metrics/_workflow-text.nix> {
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
            files = lib.mkOption {
              type = lib.types.attrsOf freeform;
              default = { };
            };
            scripts = lib.mkOption {
              type = lib.types.attrsOf freeform;
              default = { };
            };
            treefmt = lib.mkOption {
              type = freeform;
              default = { };
            };
            linters = lib.mkOption {
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

  enabled = {
    presets.ci.github_actions.pr-metrics.enable = true;
  };

  prMetricsSha = "microsoft/PR-Metrics@ac92804a3a0c8b711ca02dd9956ac6a7f2a1d2ca";
  checkoutSha = "actions/checkout@11d5960a326750d5838078e36cf38b85af677262";

  defaultCfg = {
    action = prMetricsSha;
    actionComment = "v1.7.18";
    checkoutAction = checkoutSha;
    checkoutComment = "v4";
    fetchDepth = 0;
    baseSize = 200;
    growthRate = "2.0";
    testFactor = "1.0";
    fileMatchingPatterns = null;
    testMatchingPatterns = null;
    codeFileExtensions = null;
    continueOnError = true;
    rejectAboveMedium = true;
    exemptDraftPrs = true;
    extraWith = { };
  };
in
{
  testCiPrMetricsOptInByDefault = {
    expr =
      let
        cfg = eval { };
      in
      {
        applied = cfg.presets.ci.github_actions.pr-metrics.result.applied or false;
        enable = cfg.presets.ci.github_actions.pr-metrics.enable;
        hasMarker = cfg.stdlib.markers ? prMetrics;
        hasSync = cfg.scripts ? sync-pr-metrics-workflow;
      };
    expected = {
      applied = false;
      enable = false;
      hasMarker = false;
      hasSync = false;
    };
  };

  testCiPrMetricsPresetOwnsWorkflow = {
    expr =
      let
        cfg = eval enabled;
        marker = cfg.stdlib.markers.prMetrics or { };
        sync = cfg.scripts.sync-pr-metrics-workflow.exec or "";
      in
      {
        applied = cfg.presets.ci.github_actions.pr-metrics.result.applied or false;
        hasMarker = cfg.stdlib.markers ? prMetrics;
        action = marker.action or "";
        actionComment = marker.actionComment or "";
        checkoutAction = marker.checkoutAction or "";
        workflow = marker.workflow or "";
        baseSize = marker.baseSize or 0;
        growthRate = marker.growthRate or "";
        rejectAboveMedium = marker.rejectAboveMedium or false;
        exemptDraftPrs = marker.exemptDraftPrs or false;
        hasSync = cfg.scripts ? sync-pr-metrics-workflow;
        syncCopiesPrMetrics = contains "pr-metrics.yml" sync;
        enterHasSync = contains "sync-pr-metrics-workflow" cfg.enterShell;
      };
    expected = {
      applied = true;
      hasMarker = true;
      action = prMetricsSha;
      actionComment = "v1.7.18";
      checkoutAction = checkoutSha;
      workflow = "pr-metrics.yml";
      baseSize = 200;
      growthRate = "2.0";
      rejectAboveMedium = true;
      exemptDraftPrs = true;
      hasSync = true;
      syncCopiesPrMetrics = true;
      enterHasSync = true;
    };
  };

  testCiPrMetricsWorkflowTextDefaults = {
    expr =
      let
        yaml = workflowText defaultCfg;
      in
      {
        hasName = contains "name: PR Metrics" yaml;
        hasPullRequest = contains "pull_request:" yaml;
        hasReadyForReview = contains "ready_for_review" yaml;
        hasAction = contains prMetricsSha yaml;
        hasActionComment = contains "# v1.7.18" yaml;
        hasCheckout = contains checkoutSha yaml;
        hasCheckoutComment = contains "# v4" yaml;
        hasFetchDepth = contains "fetch-depth: 0" yaml;
        hasNoPersistCreds = contains "persist-credentials: false" yaml;
        hasBase = contains ''base-size: "200"'' yaml;
        hasGrowth = contains ''growth-rate: "2.0"'' yaml;
        hasTestFactor = contains ''test-factor: "1.0"'' yaml;
        hasContinue = contains "continue-on-error: true" yaml;
        hasReject = contains "Reject oversized PRs" yaml;
        hasGitGate = contains "git diff --numstat" yaml;
        hasFailClosed = contains "Could not determine PR size" yaml;
        hasLocSep = contains "◾" yaml;
        hasReadmeSep = contains "▪️" yaml;
        hasDraftSkip = contains "!github.event.pull_request.draft" yaml;
        hasToken = contains "PR_METRICS_ACCESS_TOKEN" yaml;
        hasRunner = contains "runs-on: ubuntu-24.04" yaml;
        hasTarget = contains "pull_request_target" yaml;
      };
    expected = {
      hasName = true;
      hasPullRequest = true;
      hasReadyForReview = true;
      hasAction = true;
      hasActionComment = true;
      hasCheckout = true;
      hasCheckoutComment = true;
      hasFetchDepth = true;
      hasNoPersistCreds = true;
      hasBase = true;
      hasGrowth = true;
      hasTestFactor = true;
      hasContinue = true;
      hasReject = true;
      hasGitGate = true;
      hasFailClosed = true;
      hasLocSep = true;
      hasReadmeSep = true;
      hasDraftSkip = true;
      hasToken = true;
      hasRunner = true;
      hasTarget = false;
    };
  };

  testCiPrMetricsOptOutRejectAndDrafts = {
    expr =
      let
        yaml = workflowText (
          defaultCfg
          // {
            rejectAboveMedium = false;
            exemptDraftPrs = false;
            continueOnError = false;
            fetchDepth = null;
            extraWith = {
              test-factor = "0.0";
            };
          }
        );
        cfg = eval {
          presets.ci.github_actions.pr-metrics = {
            enable = true;
            rejectAboveMedium = false;
            exemptDraftPrs = false;
          };
        };
        marker = cfg.stdlib.markers.prMetrics;
      in
      {
        inherit (marker) rejectAboveMedium exemptDraftPrs;
        yamlLacksReject = contains "Reject oversized PRs" yaml;
        yamlLacksDraftIf = contains "!github.event.pull_request.draft" yaml;
        yamlLacksContinue = contains "continue-on-error" yaml;
        yamlLacksFetchDepth = contains "fetch-depth" yaml;
        yamlHasNoPersist = contains "persist-credentials: false" yaml;
        yamlHasTest0 = contains ''test-factor: "0.0"'' yaml;
      };
    expected = {
      rejectAboveMedium = false;
      exemptDraftPrs = false;
      yamlLacksReject = false;
      yamlLacksDraftIf = false;
      yamlLacksContinue = false;
      yamlLacksFetchDepth = false;
      yamlHasNoPersist = true;
      yamlHasTest0 = true;
    };
  };

  testCiPrMetricsYamlSafeGlobs = {
    expr =
      let
        yaml = workflowText (
          defaultCfg
          // {
            extraWith = {
              "file-matching-patterns" = "**/*\n!**/package-lock.json";
            };
          }
        );
      in
      {
        hasQuotedGlob = contains ''"**/*'' yaml;
        hasEscapedNewline = contains "\\n" yaml;
      };
    expected = {
      hasQuotedGlob = true;
      hasEscapedNewline = true;
    };
  };
}
