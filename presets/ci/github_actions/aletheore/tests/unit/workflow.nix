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

  defaultCfg = {
    action = "Aletheore/Aletheore@v0.9.22";
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
        cfg = eval { };
        marker = cfg.stdlib.markers.aletheore or { };
        sync = cfg.scripts.sync-aletheore-workflow.exec or "";
      in
      {
        applied = cfg.presets.ci.github_actions.aletheore.result.applied or false;
        hasMarker = cfg.stdlib.markers ? aletheore;
        action = marker.action or "";
        workflow = marker.workflow or "";
        failOnNewSecrets = marker.failOnNewSecrets or false;
        failOnNewVulnerabilities = marker.failOnNewVulnerabilities or true;
        postPrComment = marker.postPrComment or false;
        hasSync = cfg.scripts ? sync-aletheore-workflow;
        syncCopiesAletheore = contains "aletheore.yml" sync;
        enterHasSync = contains "sync-aletheore-workflow" cfg.enterShell;
      };
    expected = {
      applied = true;
      hasMarker = true;
      action = "Aletheore/Aletheore@v0.9.22";
      workflow = "aletheore.yml";
      failOnNewSecrets = true;
      failOnNewVulnerabilities = false;
      postPrComment = true;
      hasSync = true;
      syncCopiesAletheore = true;
      enterHasSync = true;
    };
  };

  testCiAletheoreDisableRemovesWriter = {
    expr =
      let
        cfg = eval { };
        disabled = eval {
          presets.ci.github_actions.aletheore.enable = false;
        };
      in
      {
        defaultApplied = cfg.presets.ci.github_actions.aletheore.result.applied or false;
        disabledApplied = disabled.presets.ci.github_actions.aletheore.result.applied or false;
        disabledHasMarker = disabled.stdlib.markers ? aletheore;
        disabledHasSync = disabled.scripts ? sync-aletheore-workflow;
        actionOption = cfg.presets.ci.github_actions.aletheore.action;
        failOnNewSecretsOption = cfg.presets.ci.github_actions.aletheore.failOnNewSecrets;
      };
    expected = {
      defaultApplied = true;
      disabledApplied = false;
      disabledHasMarker = false;
      disabledHasSync = false;
      actionOption = "Aletheore/Aletheore@v0.9.22";
      failOnNewSecretsOption = true;
    };
  };

  testCiAletheoreWorkflowTextDefaults = {
    expr =
      let
        yaml = workflowText defaultCfg;
      in
      {
        hasName = contains "name: Aletheore" yaml;
        hasPullRequest = contains "pull_request:" yaml;
        lacksTarget = contains "pull_request_target" yaml;
        hasAction = contains "Aletheore/Aletheore@v0.9.22" yaml;
        hasFailSecrets = contains "fail-on-new-secrets: true" yaml;
        hasFailVulns = contains "fail-on-new-vulnerabilities: false" yaml;
        hasFailLayers = contains "fail-on-new-layer-violations: false" yaml;
        hasPost = contains "post-pr-comment: true" yaml;
        hasIssuesWrite = contains "issues: write" yaml;
        hasPrWrite = contains "pull-requests: write" yaml;
        hasRunner = contains "runs-on: ubuntu-24.04" yaml;
        # Action checkouts base/head itself — host workflow has no checkout step.
        hasCheckout = contains "actions/checkout" yaml;
      };
    expected = {
      hasName = true;
      hasPullRequest = true;
      lacksTarget = false;
      hasAction = true;
      hasFailSecrets = true;
      hasFailVulns = true;
      hasFailLayers = true;
      hasPost = true;
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
