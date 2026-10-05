# Example only — not loaded by modules/devenv.nix.
#
# Shows how a consumer enables microsoft/PR-Metrics (Marketplace: PR Metrics)
# with reject-above-medium. The framework preset lives at
# presets/ci/github_actions/pr-metrics.nix (attrpath ci.github_actions.pr-metrics)
# and defaults to off (marketplace Action). Set enable = true in devenv.nix /
# devenv.local.nix; enterShell syncs .github/workflows/pr-metrics.yml — commit
# that file.
#
#   presets.ci.github_actions.pr-metrics.enable = true;
#
# Defaults (when enabled):
#   - baseSize = 200, growthRate = "2.0" → medium ends at 800 product-code lines
#   - rejectAboveMedium = true → L / XL / N XL fail the job
#   - exemptDraftPrs = true → drafts skipped (ready_for_review re-runs)
#   - continueOnError = true on the annotate step (upstream recommendation)
#
# Opt-out / override:
#
#   presets.ci.github_actions.pr-metrics.enable = false;           # remove gate
#   presets.ci.github_actions.pr-metrics.rejectAboveMedium = false; # annotate only
#   presets.ci.github_actions.pr-metrics.baseSize = 400;           # widen XS/M
#
# Optional knobs:
#
#   presets.ci.github_actions.pr-metrics = {
#     enable = true;
#     action = "microsoft/PR-Metrics@v1.7.18";
#     baseSize = 200;
#     growthRate = "2.0";
#     testFactor = "1.0";
#     rejectAboveMedium = true;
#     exemptDraftPrs = true;
#     extraWith = {
#       # test-factor = "0.0";
#     };
#   };
#
# This template dogfoods the same enable in the root devenv.nix.
{ lib }:
{
  # Documentation-only sentinel (examples/ is not in defaultRoots).
  meta.description = lib.mkDefault ''
    Enable presets.ci.github_actions.pr-metrics in devenv.nix / devenv.local.nix.
  '';
}
