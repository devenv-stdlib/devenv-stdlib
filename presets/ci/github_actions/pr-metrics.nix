# Composable CI preset: owns pr-metrics.yml for microsoft/PR-Metrics.
# Attrpath: ci.github_actions.pr-metrics.
#
# PR Metrics annotates PR titles with size (XS/S/M/L/XL/…) and test-coverage
# indicators, and posts a metrics comment. GHA-only — not treefmt, not prek,
# and not a local hook. Sibling to ci.github_actions.anti-slop (PR quality)
# and ci.github_actions.aletheore (evidence review).
#
# The marketplace Action has no fail-on-size input (docs recommend
# continue-on-error). This preset adds a default reject gate for sizes above
# medium (L / XL / N XL), matching "PRs stay small/contained".
#
# Size bands (action defaults base-size=200, growth-rate=2.0):
#   XS < 200; S < 400; M < 800; L < 1600; XL+ beyond.
# So "medium" means up to baseSize * growthRate^2 product-code lines (800).
#
# Opt-in (dogfood parity): enable defaults to false. Projects that want the
# check set presets.ci.github_actions.pr-metrics.enable = true; this template
# dogfoods that in devenv.nix. Turn off and remove .github/workflows/pr-metrics.yml
# when disabling.
#
# Draft PRs: exempt by default (exemptDraftPrs), same spirit as anti-slop —
# the Action docs do not define draft behavior; WIP/agent drafts should not
# fail the size gate while iterating. ready_for_review re-runs the check.
#
# Parallel sibling of Lint (prek): own workflow (no needs: lint). Failures fail
# the `PR size (pr-metrics)` check; require that context on the branch ruleset
# to stop merge (not the bare job id).
#
# Marketplace: https://github.com/marketplace/actions/pr-metrics
# Upstream: https://github.com/microsoft/PR-Metrics
{ lib, ... }:
let
  # Underscore prefix so devenv.load does not treat this as a preset leaf.
  inherit (import ./pr-metrics/_workflow-text.nix { inherit lib; }) workflowText;
in
{
  path = [
    "ci"
    "github_actions"
    "pr-metrics"
  ];
  description = ''
    Opt-in: write .github/workflows/pr-metrics.yml for microsoft/PR-Metrics
    (GHA-only PR size / test-coverage indicators). Runs in parallel with Lint
    (prek); check context `PR size (pr-metrics)` fails on reject-above-medium —
    add it to the branch ruleset after merge to block merge. Rejects PRs larger
    than medium by default. Enable with
    presets.ci.github_actions.pr-metrics.enable = true. Complements anti-slop /
    Aletheore; not a local hook.
  '';
  # Always discoverable; enable is opt-in (mkDefault false below).
  when = _: true;

  module =
    { lib, ... }:
    {
      options.presets.ci.github_actions.pr-metrics = {
        action = lib.mkOption {
          type = lib.types.str;
          # Pin the release by commit SHA; pull_request does not make a tag
          # immutable (same posture as anti-slop). Human-readable tag stays in
          # actionComment.
          default = "microsoft/PR-Metrics@ac92804a3a0c8b711ca02dd9956ac6a7f2a1d2ca";
          description = ''
            Marketplace Action pin (`owner/repo@sha`). Prefer a full commit SHA
            over a mutable tag; put the release tag in `actionComment`.
          '';
        };
        actionComment = lib.mkOption {
          type = lib.types.str;
          default = "v1.7.18";
          description = ''
            Trailing YAML comment on the generated `uses:` line (release tag for
            readability). Empty string omits the comment.
          '';
        };
        checkoutAction = lib.mkOption {
          type = lib.types.str;
          # actions/checkout@v4 tip peel (CodeRabbit-verified); human label in
          # checkoutComment.
          default = "actions/checkout@11d5960a326750d5838078e36cf38b85af677262";
          description = "Checkout Action pin (full commit SHA) used before microsoft/PR-Metrics.";
        };
        checkoutComment = lib.mkOption {
          type = lib.types.str;
          default = "v4";
          description = ''
            Trailing YAML comment on the checkout `uses:` line. Empty string
            omits the comment.
          '';
        };
        fetchDepth = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.unsigned;
          # Stacked / rebase-heavy histories need full git history for diffs.
          default = 0;
          description = ''
            `actions/checkout` `fetch-depth`. `0` fetches full history (needed
            for non-linear git history per PR Metrics docs). `null` omits the
            input (shallow default).
          '';
        };
        baseSize = lib.mkOption {
          type = lib.types.ints.positive;
          default = 200;
          description = ''
            PR Metrics `base-size` — max new product-code lines for an XS PR.
            With growthRate=2.0, medium ends at baseSize * 4 (800).
          '';
        };
        growthRate = lib.mkOption {
          type = lib.types.str;
          default = "2.0";
          description = ''
            PR Metrics `growth-rate` — multiplier between size bands. Defaults
            match upstream (2.0 → S@400, M@800, L@1600 product lines).
          '';
        };
        testFactor = lib.mkOption {
          type = lib.types.str;
          default = "1.0";
          description = ''
            PR Metrics `test-factor` — expected test lines per product line.
            Set to `"0"` / `"0.0"` to skip test-coverage reporting.
          '';
        };
        fileMatchingPatterns = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            PR Metrics `file-matching-patterns` (multiline globs). `null` leaves
            the Action default (`**/*` minus common lockfiles).
          '';
        };
        testMatchingPatterns = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            PR Metrics `test-matching-patterns` (multiline globs). `null` leaves
            the Action default (paths containing `test` / `.spec`).
          '';
        };
        codeFileExtensions = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            PR Metrics `code-file-extensions` (newline-separated). `null` uses
            the monorepo default (`nix` / `yml` / `yaml` — includes Nix, excludes
            Markdown). The reject-oversized gate applies the same list so Action
            annotations and the size check measure the same product-code files.
            `""` omits the Action input (upstream top-10 defaults); the size
            gate still applies that same documented default extension list so it
            does not count every eligible file. Any other string replaces the
            Action default set (no merge).
          '';
        };
        continueOnError = lib.mkOption {
          type = lib.types.bool;
          # Upstream recommends this so annotation failures do not hard-stop CI;
          # the reject step below is the intentional size gate.
          default = true;
          description = ''
            `continue-on-error` on the microsoft/PR-Metrics step (upstream
            recommendation). Size rejection is a separate step.
          '';
        };
        rejectAboveMedium = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Fail the job when git product-code adds (same extensions as
            `codeFileExtensions`) meet or exceed the medium ceiling
            (`baseSize * growthRate²`). Requires the PR base commit locally
            (`fetchDepth = 0` by default); missing base fails closed — no title
            prefix trust. Opt out with `false` to annotate only. Raise
            `baseSize` / `growthRate` to widen what counts as medium.
          '';
        };
        exemptDraftPrs = lib.mkOption {
          type = lib.types.bool;
          # Same default spirit as anti-slop: draft/WIP agent PRs should not
          # trip the size gate while iterating. Action docs are silent on drafts.
          default = true;
          description = ''
            Skip the job while the PR is a draft (`ready_for_review` re-runs).
            Chosen to match anti-slop `exemptDraftPrs`; upstream docs do not
            specify draft behavior.
          '';
        };
        extraWith = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = ''
            Extra `with:` inputs passed through to microsoft/PR-Metrics as raw
            YAML scalars. Same keys override the named options above.
          '';
          example = {
            test-factor = "0.0";
          };
        };
      };

      # Marketplace Action — opt-in per CI dogfood parity (not on by default).
      # leafOptions sets enable default true; this mkDefault wins until the
      # consumer (or this template's devenv.nix) sets enable = true.
      config.presets.ci.github_actions.pr-metrics.enable = lib.mkDefault false;
    };

  project =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.presets.ci.github_actions.pr-metrics;
      text = workflowText cfg;
      workflowFile = pkgs.writeText "pr-metrics.yml" text;
    in
    {
      # Structured marker for tests / future stdlib.report sections.
      stdlib.markers.prMetrics = {
        enable = true;
        inherit (cfg)
          action
          actionComment
          checkoutAction
          checkoutComment
          fetchDepth
          baseSize
          growthRate
          testFactor
          continueOnError
          rejectAboveMedium
          exemptDraftPrs
          ;
        workflow = "pr-metrics.yml";
      };

      scripts.sync-pr-metrics-workflow.exec = ''
        set -euo pipefail
        dest="$DEVENV_ROOT/.github/workflows/pr-metrics.yml"
        mkdir -p "$(dirname "$dest")"
        tmp="$(mktemp)"
        cp ${lib.escapeShellArg workflowFile} "$tmp"
        if ! cmp -s "$tmp" "$dest" 2>/dev/null; then
          mv "$tmp" "$dest"
          echo "wrote .github/workflows/pr-metrics.yml"
        else
          rm -f "$tmp"
        fi
      '';

      enterShell = ''
        sync-pr-metrics-workflow
      '';
    };
}
