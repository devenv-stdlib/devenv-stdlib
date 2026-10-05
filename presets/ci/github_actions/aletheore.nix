# Composable CI preset: owns aletheore.yml for Aletheore/Aletheore and enables
# the local Aletheore CLI tool (tools.scanners.aletheore → catalog pipx pin).
# Attrpath: ci.github_actions.aletheore.
#
# Aletheore is a GitHub Action that scans a PR's base and head refs and posts
# an evidence-grounded diff (secrets, dependency vulnerabilities, layer
# violations) as a PR comment, inline annotations, and Step Summary. GHA-only
# — not treefmt, not prek, and not a local hook. Sibling to
# ci.github_actions.anti-slop (PR quality gate); this is a review / evidence
# attachment, not an AttachmentPlan cache/coverage step.
#
# Parallel sibling of Lint (prek): own workflow (no needs: lint). Failures fail
# the `Security review (Aletheore)` check; require that context on the branch
# ruleset to stop merge (not the bare job id).
#
# Opt out with presets.ci.github_actions.aletheore.enable = false and remove
# .github/workflows/aletheore.yml (also drops tools.aletheore). Aletheore
# Community is PolyForm Noncommercial — org/commercial use needs a separate
# license from upstream. Paid Aletheore AIR plans: https://www.aletheore.com
{ lib, tools, ... }:
let
  # Underscore prefix so devenv.load does not treat this as a preset leaf.
  inherit (import ./aletheore/_workflow-text.nix { inherit lib; }) workflowText;
in
{
  path = [
    "ci"
    "github_actions"
    "aletheore"
  ];
  description = ''
    Generate .github/workflows/aletheore.yml for Aletheore/Aletheore (GHA-only
    evidence-grounded PR review diffs) and enable the local Aletheore CLI
    (tools.scanners.aletheore; catalog pipx:aletheore). Runs in parallel with
    Lint (prek); check context `Security review (Aletheore)` fails on configured
    fail-on-* gates — add it to the branch ruleset after merge to block merge.
    Complements anti-slop / CodeRabbit; not a local hook. Product site / paid
    plans: https://www.aletheore.com
  '';
  # Always available; presets.ci.github_actions.aletheore.enable turns it off.
  when = _: true;

  # Local CLI leaf (mise/pipx catalog pin) — same pattern as ide.coderabbit → CLI.
  tools = [ tools.scanners.aletheore ];

  module =
    { lib, ... }:
    {
      options.presets.ci.github_actions.aletheore = {
        action = lib.mkOption {
          type = lib.types.str;
          # Immutable commit for v0.9.22 — issues/pull-requests: write must not
          # follow a movable tag. Keep the human version in actionComment.
          # Peeled from refs/tags/v0.9.22 → 24f816e9297f87853b09fe514081863dc6604d30.
          default = "Aletheore/Aletheore@24f816e9297f87853b09fe514081863dc6604d30";
          description = ''
            Marketplace Action pin (`owner/repo@sha`). Prefer a full commit SHA
            over a mutable tag; put the release tag in `actionComment`.
          '';
        };
        actionComment = lib.mkOption {
          type = lib.types.str;
          default = "v0.9.22";
          description = ''
            Trailing YAML comment on the generated `uses:` line (release tag for
            readability). Empty string omits the comment.
          '';
        };
        failOnNewSecrets = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Aletheore `fail-on-new-secrets` — fail the job on new real secrets.";
        };
        failOnNewVulnerabilities = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Aletheore `fail-on-new-vulnerabilities` — fail on new dependency vulns.";
        };
        failOnNewLayerViolations = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Aletheore `fail-on-new-layer-violations` — fail on new layer-convention violations.";
        };
        full = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Aletheore `full` — post the raw diff instead of the curated summary.";
        };
        postPrComment = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Aletheore `post-pr-comment`. When true, the generated workflow uses
            a same-repo gate
            (`github.event.pull_request.head.repo.full_name == github.repository`)
            so fork PRs (read-only `GITHUB_TOKEN`) skip commenting; scan /
            annotations / Step Summary still run. Needs `pull-requests: write`
            and `issues: write` on same-repo PRs.
          '';
        };
        extraWith = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = ''
            Extra `with:` inputs passed through to Aletheore/Aletheore as raw
            YAML scalars (e.g. `{ full = "true"; }`). Same keys override the
            named options above.
          '';
          example = {
            full = "true";
          };
        };
      };
    };

  project =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.presets.ci.github_actions.aletheore;
      text = workflowText cfg;
      workflowFile = pkgs.writeText "aletheore.yml" text;
    in
    {
      # Structured marker for tests / future stdlib.report sections.
      stdlib.markers.aletheore = {
        enable = true;
        inherit (cfg)
          action
          actionComment
          failOnNewSecrets
          failOnNewVulnerabilities
          failOnNewLayerViolations
          full
          postPrComment
          ;
        workflow = "aletheore.yml";
      };

      scripts.sync-aletheore-workflow.exec = ''
        set -euo pipefail
        dest="$DEVENV_ROOT/.github/workflows/aletheore.yml"
        mkdir -p "$(dirname "$dest")"
        # Same filesystem as dest so mv is an atomic rename (not cross-fs copy).
        tmp="$(mktemp "$(dirname "$dest")/.aletheore.yml.XXXXXX")"
        cp ${lib.escapeShellArg workflowFile} "$tmp"
        chmod 0644 "$tmp"
        if ! cmp -s "$tmp" "$dest" 2>/dev/null; then
          mv "$tmp" "$dest"
          echo "wrote .github/workflows/aletheore.yml"
        else
          rm -f "$tmp"
        fi
      '';

      enterShell = ''
        sync-aletheore-workflow
      '';
    };
}
