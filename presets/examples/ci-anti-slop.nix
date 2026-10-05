# Example only — not loaded by modules/devenv.nix.
#
# Shows how a consumer enables the peakoss/anti-slop PR quality gate. The
# framework preset lives at presets/ci/github_actions/anti-slop.nix (attrpath
# ci.github_actions.anti-slop) and defaults to off (marketplace Action). Set
# enable = true in devenv.nix / devenv.local.nix; enterShell syncs
# .github/workflows/pr-quality.yml — commit that file.
#
#   presets.ci.github_actions.anti-slop.enable = true;
#
# Optional knobs:
#
#   presets.ci.github_actions.anti-slop = {
#     enable = true;
#     action = "peakoss/anti-slop@v0.3.0";
#     maxFailures = 4;
#     closePr = true;
#     exemptDraftPrs = true;
#     extraWith = {
#       # "min-account-age" = "0";
#     };
#   };
#
# This template dogfoods the same enable in the root devenv.nix.
{ }:
{
}
