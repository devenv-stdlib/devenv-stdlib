# Composable CI preset: owns pr-quality.yml for peakoss/anti-slop.
# Attrpath: ci.github_actions.anti-slop.
#
# anti-slop is a GitHub Action PR-quality / AI-slop gate (pull_request).
# It is GHA-only — not treefmt, not prek, and not a local hook.
# Uses pull_request (not pull_request_target) so the workflow file on the PR
# head is eligible to run — required for dogfood on the introducing PR and
# for any tip that has not yet landed on the repository default branch.
#
# Opt-in (dogfood parity): enable defaults to false. Projects that want the
# check set presets.ci.github_actions.anti-slop.enable = true; this template
# dogfoods that in devenv.nix. Turn off and remove .github/workflows/pr-quality.yml
# when disabling.
#
# Parallel sibling of Lint (prek): own workflow (no needs: lint). Failures fail
# the `anti-slop` check; require that context on the branch ruleset to stop merge.
{ lib, ... }:
let
  # Underscore prefix so devenv.load does not treat this as a preset leaf.
  inherit (import ./anti-slop/_workflow-text.nix { inherit lib; }) workflowText;
in
{
  path = [
    "ci"
    "github_actions"
    "anti-slop"
  ];
  description = ''
    Opt-in: write .github/workflows/pr-quality.yml for peakoss/anti-slop
    (GHA-only PR quality / AI-slop checks). Runs in parallel with Lint (prek);
    check context `anti-slop` fails the job on gate failure — add it to the
    branch ruleset after merge to block merge. Enable with
    presets.ci.github_actions.anti-slop.enable = true. Complements prek; not a
    local hook.
  '';
  # Always discoverable; enable is opt-in (mkDefault false below).
  when = _: true;

  module =
    { lib, ... }:
    {
      options.presets.ci.github_actions.anti-slop = {
        action = lib.mkOption {
          type = lib.types.str;
          # Immutable commit for v0.3.0 — pull-requests: write must not follow
          # a movable tag. Keep the human version in actionComment.
          default = "peakoss/anti-slop@57858eead489d08b255fab2af45a506c2ca6eab2";
          description = ''
            Marketplace Action pin (`owner/repo@sha`). Default is the v0.3.0
            release commit (not the movable `v0.3.0` / `v0` tags).
          '';
        };
        actionComment = lib.mkOption {
          type = lib.types.str;
          default = "v0.3.0";
          description = ''
            Trailing YAML comment on the generated `uses:` line (release tag
            label for humans). Empty string omits the comment.
          '';
        };
        maxFailures = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 4;
          description = "anti-slop `max-failures` — how many check failures trigger failure actions.";
        };
        closePr = lib.mkOption {
          type = lib.types.bool;
          # false: dogfood / agent PRs often trip marketplace defaults (commit
          # author match, description length, …). Scan and report without
          # auto-closing; consumers can set true when they want close-on-fail.
          default = false;
          description = "anti-slop `close-pr` — close the PR when max-failures is reached.";
        };
        exemptDraftPrs = lib.mkOption {
          type = lib.types.bool;
          # Draft agent / WIP PRs should not be auto-closed while iterating.
          default = true;
          description = "anti-slop `exempt-draft-prs` — skip all checks on draft PRs.";
        };
        exemptAuthorAssociation = lib.mkOption {
          type = lib.types.str;
          # Marketplace default is OWNER,MEMBER,COLLABORATOR. Empty string
          # disables all author-association exemptions so owners are scanned.
          default = "";
          description = ''
            anti-slop `exempt-author-association` — comma-separated GitHub
            author associations exempt from all checks. Empty (default) means
            no association is exempt (owners included). Marketplace default is
            `OWNER,MEMBER,COLLABORATOR`.
          '';
          example = "MEMBER,COLLABORATOR";
        };
        requireCommitAuthorMatch = lib.mkOption {
          type = lib.types.bool;
          # Marketplace default true. Agent / co-authored tips use a different
          # git author than the PR opener; LLM-free projects can set true.
          default = false;
          description = ''
            anti-slop `require-commit-author-match` — require every commit
            author to match the PR opener. Default false; set true if the
            project disallows LLM / third-party commit authors.
          '';
        };
        requireMaintainerCanModify = lib.mkOption {
          type = lib.types.bool;
          # Marketplace default true, but GitHub's maintainer_can_modify is
          # only meaningful for fork PRs — same-repo PRs always report false
          # even when maintainers already have push access (peakoss/anti-slop
          # does not special-case same-repo). Default false for dogfood.
          default = false;
          description = ''
            anti-slop `require-maintainer-can-modify`. Default false: the
            marketplace check fails every same-repo PR because GitHub always
            sets `maintainer_can_modify` false when head and base share a
            repository. Enable only if you primarily receive fork PRs.
          '';
        };
        extraWith = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = ''
            Extra `with:` inputs for peakoss/anti-slop. Values are emitted as
            YAML double-quoted scalars via `builtins.toJSON` so newline-separated
            inputs (e.g. `blocked-paths`) stay one line. Same keys override the
            named options above.
          '';
          example = {
            require-description = "true";
            "min-account-age" = "0";
            "blocked-paths" = "README.md\nSECURITY.md";
          };
        };
      };

      # Marketplace Action — opt-in per CI dogfood parity (not on by default).
      # leafOptions sets enable default true; this mkDefault wins until the
      # consumer (or this template's devenv.nix) sets enable = true.
      config.presets.ci.github_actions.anti-slop.enable = lib.mkDefault false;
    };

  project =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.presets.ci.github_actions.anti-slop;
      text = workflowText cfg;
      workflowFile = pkgs.writeText "pr-quality.yml" text;
    in
    {
      # Structured marker for tests / future stdlib.report sections.
      stdlib.markers.antiSlop = {
        enable = true;
        inherit (cfg)
          action
          actionComment
          maxFailures
          closePr
          exemptDraftPrs
          exemptAuthorAssociation
          requireCommitAuthorMatch
          requireMaintainerCanModify
          ;
        workflow = "pr-quality.yml";
      };

      scripts.sync-anti-slop-workflow.exec = ''
        set -euo pipefail
        dest="$DEVENV_ROOT/.github/workflows/pr-quality.yml"
        mkdir -p "$(dirname "$dest")"
        tmp="$(mktemp)"
        cp ${lib.escapeShellArg workflowFile} "$tmp"
        if ! cmp -s "$tmp" "$dest" 2>/dev/null; then
          mv "$tmp" "$dest"
          echo "wrote .github/workflows/pr-quality.yml"
        else
          rm -f "$tmp"
        fi
      '';

      enterShell = ''
        sync-anti-slop-workflow
      '';
    };
}
