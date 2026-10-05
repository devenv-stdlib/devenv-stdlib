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
    action = "peakoss/anti-slop@v0.3.0";
    maxFailures = 4;
    closePr = true;
    exemptDraftPrs = true;
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
        hasSync = cfg.scripts ? sync-anti-slop-workflow;
        syncCopiesPrQuality = contains "pr-quality.yml" sync;
        enterHasSync = contains "sync-anti-slop-workflow" cfg.enterShell;
      };
    expected = {
      applied = true;
      hasMarker = true;
      action = "peakoss/anti-slop@v0.3.0";
      workflow = "pr-quality.yml";
      maxFailures = 4;
      closePr = true;
      exemptDraftPrs = true;
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
        hasTarget = contains "pull_request_target" yaml;
        hasAction = contains "peakoss/anti-slop@v0.3.0" yaml;
        hasMax = contains "max-failures: 4" yaml;
        hasClose = contains "close-pr: true" yaml;
        hasExemptDraft = contains "exempt-draft-prs: true" yaml;
        hasRunner = contains "runs-on: ubuntu-24.04" yaml;
        # No checkout — pull_request_target must not run untrusted code.
        hasCheckout = contains "actions/checkout" yaml;
      };
    expected = {
      hasName = true;
      hasTarget = true;
      hasAction = true;
      hasMax = true;
      hasClose = true;
      hasExemptDraft = true;
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
            };
          };
        };
        marker = cfg.stdlib.markers.antiSlop;
      in
      {
        inherit (marker) maxFailures closePr;
        yamlHasAge = contains "min-account-age: 0" yaml;
        # extraWith overrides the named max-failures scalar in YAML.
        yamlHasMax9 = contains "max-failures: 9" yaml;
        yamlLacksMax2 = contains "max-failures: 2" yaml;
        hasSync = cfg.scripts ? sync-anti-slop-workflow;
      };
    expected = {
      maxFailures = 2;
      closePr = false;
      yamlHasAge = true;
      yamlHasMax9 = true;
      yamlLacksMax2 = false;
      hasSync = true;
    };
  };
}
