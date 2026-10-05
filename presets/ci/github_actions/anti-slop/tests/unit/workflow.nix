# Real anti-slop CI preset: owns pr-quality.yml sync + marker surface.
# Framework default is opt-in (enable = false); dogfood sets enable = true.
{ lib, ... }:
let
  devenvLoad = import <devenv4monorepo/stdlib/devenv.nix> { inherit lib; };
  presetRoot = <devenv4monorepo/presets>;
  toolsRoot = <devenv4monorepo/tools>;
  inherit
    (import <devenv4monorepo/presets/ci/github_actions/anti-slop/_workflow-text.nix> {
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
    presets.ci.github_actions.anti-slop.enable = true;
  };

  defaultCfg = {
    action = "peakoss/anti-slop@57858eead489d08b255fab2af45a506c2ca6eab2";
    actionComment = "v0.3.0";
    maxFailures = 4;
    closePr = false;
    exemptDraftPrs = true;
    exemptAuthorAssociation = "";
    requireCommitAuthorMatch = false;
    requireMaintainerCanModify = false;
    extraWith = { };
  };
in
{
  testCiAntiSlopOptInByDefault = {
    expr =
      let
        cfg = eval { };
      in
      {
        applied = cfg.presets.ci.github_actions.anti-slop.result.applied or false;
        enable = cfg.presets.ci.github_actions.anti-slop.enable;
        hasMarker = cfg.stdlib.markers ? antiSlop;
        hasSync = cfg.scripts ? sync-anti-slop-workflow;
      };
    expected = {
      applied = false;
      enable = false;
      hasMarker = false;
      hasSync = false;
    };
  };

  testCiAntiSlopPresetOwnsWorkflow = {
    expr =
      let
        cfg = eval enabled;
        marker = cfg.stdlib.markers.antiSlop or { };
        sync = cfg.scripts.sync-anti-slop-workflow.exec or "";
      in
      {
        applied = cfg.presets.ci.github_actions.anti-slop.result.applied or false;
        hasMarker = cfg.stdlib.markers ? antiSlop;
        action = marker.action or "";
        workflow = marker.workflow or "";
        maxFailures = marker.maxFailures or 0;
        closePr = marker.closePr or false;
        exemptDraftPrs = marker.exemptDraftPrs or false;
        exemptAuthorAssociation = marker.exemptAuthorAssociation or "unset";
        requireCommitAuthorMatch = marker.requireCommitAuthorMatch or true;
        requireMaintainerCanModify = marker.requireMaintainerCanModify or true;
        hasSync = cfg.scripts ? sync-anti-slop-workflow;
        syncCopiesPrQuality = contains "pr-quality.yml" sync;
        enterHasSync = contains "sync-anti-slop-workflow" cfg.enterShell;
      };
    expected = {
      applied = true;
      hasMarker = true;
      action = "peakoss/anti-slop@57858eead489d08b255fab2af45a506c2ca6eab2";
      workflow = "pr-quality.yml";
      maxFailures = 4;
      closePr = false;
      exemptDraftPrs = true;
      exemptAuthorAssociation = "";
      requireCommitAuthorMatch = false;
      requireMaintainerCanModify = false;
      hasSync = true;
      syncCopiesPrQuality = true;
      enterHasSync = true;
    };
  };

  testCiAntiSlopWorkflowTextDefaults = {
    expr =
      let
        yaml = workflowText defaultCfg;
      in
      {
        hasName = contains "name: PR Quality" yaml;
        # pull_request (not _target): workflow on the PR head can run / dogfood.
        hasPullRequest = contains "pull_request:" yaml;
        lacksTarget = !(contains "pull_request_target" yaml);
        # ready_for_review: fresh payload after draft→ready (re-runs freeze draft).
        hasReadyForReview = contains "ready_for_review" yaml;
        hasOpened = contains "- opened" yaml;
        hasSynchronize = contains "- synchronize" yaml;
        hasReopened = contains "- reopened" yaml;
        hasAction = contains "peakoss/anti-slop@57858eead489d08b255fab2af45a506c2ca6eab2" yaml;
        hasActionComment = contains "# v0.3.0" yaml;
        hasMax = contains ''max-failures: "4"'' yaml;
        hasClose = contains ''close-pr: "false"'' yaml;
        hasExemptDraft = contains ''exempt-draft-prs: "true"'' yaml;
        # Empty association list: owners/members/collaborators are scanned too.
        hasExemptAuthorEmpty = contains ''exempt-author-association: ""'' yaml;
        lacksOwnerExempt = !(contains "OWNER" yaml);
        hasCommitAuthorMatchFalse = contains ''require-commit-author-match: "false"'' yaml;
        hasMaintainerCanModifyFalse = contains ''require-maintainer-can-modify: "false"'' yaml;
        hasRunner = contains "runs-on: ubuntu-24.04" yaml;
        # No checkout — action uses the GitHub API only (no untrusted PR tree).
        hasCheckout = contains "actions/checkout" yaml;
      };
    expected = {
      hasName = true;
      hasPullRequest = true;
      lacksTarget = true;
      hasReadyForReview = true;
      hasOpened = true;
      hasSynchronize = true;
      hasReopened = true;
      hasAction = true;
      hasActionComment = true;
      hasMax = true;
      hasClose = true;
      hasExemptDraft = true;
      hasExemptAuthorEmpty = true;
      lacksOwnerExempt = true;
      hasCommitAuthorMatchFalse = true;
      hasMaintainerCanModifyFalse = true;
      hasRunner = true;
      hasCheckout = false;
    };
  };

  testCiAntiSlopExtraWithOverrides = {
    expr =
      let
        yaml = workflowText (
          defaultCfg
          // {
            maxFailures = 2;
            closePr = false;
            extraWith = {
              "min-account-age" = "0";
              max-failures = "9";
              "blocked-paths" = "README.md\nSECURITY.md";
            };
          }
        );
        cfg = eval {
          presets.ci.github_actions.anti-slop = {
            enable = true;
            maxFailures = 2;
            closePr = false;
            extraWith = {
              "min-account-age" = "0";
              max-failures = "9";
              "blocked-paths" = "README.md\nSECURITY.md";
            };
          };
        };
        marker = cfg.stdlib.markers.antiSlop;
      in
      {
        inherit (marker) maxFailures closePr;
        yamlHasAge = contains ''min-account-age: "0"'' yaml;
        # extraWith overrides the named max-failures scalar in YAML.
        yamlHasMax9 = contains ''max-failures: "9"'' yaml;
        yamlLacksMax2 = contains ''max-failures: "2"'' yaml;
        # Newline-separated inputs stay one YAML scalar (JSON-quoted).
        yamlHasBlocked = contains ''blocked-paths: "README.md\nSECURITY.md"'' yaml;
        yamlLacksBareBlockedLine =
          !(contains "\nSECURITY.md" (
            builtins.replaceStrings [ ''blocked-paths: "README.md\nSECURITY.md"'' ] [ "" ] yaml
          ));
        hasSync = cfg.scripts ? sync-anti-slop-workflow;
      };
    expected = {
      maxFailures = 2;
      closePr = false;
      yamlHasAge = true;
      yamlHasMax9 = true;
      yamlLacksMax2 = false;
      yamlHasBlocked = true;
      yamlLacksBareBlockedLine = true;
      hasSync = true;
    };
  };
}
