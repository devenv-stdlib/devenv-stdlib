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
#     action = "peakoss/anti-slop@57858eead489d08b255fab2af45a506c2ca6eab2"; # v0.3.0
#     maxFailures = 4;
#     closePr = false; # true only if you want close-on-fail
#     exemptDraftPrs = true;
#     # Empty = no author-association exemptions (owners scanned too).
#     # Marketplace default is "OWNER,MEMBER,COLLABORATOR".
#     exemptAuthorAssociation = "";
#     extraWith = {
#       # "min-account-age" = "0";
#     };
#   };
#
# This template dogfoods the same enable in the root devenv.nix.
{ lib }:
{
  # Documentation-only sentinel (examples/ is not in defaultRoots).
  meta.description = lib.mkDefault ''
    Enable presets.ci.github_actions.anti-slop in devenv.nix / devenv.local.nix.
  '';
}
