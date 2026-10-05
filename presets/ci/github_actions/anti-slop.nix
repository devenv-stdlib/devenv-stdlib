# Composable CI preset: owns pr-quality.yml for peakoss/anti-slop.
# Attrpath: ci.github_actions.anti-slop.
#
# anti-slop is a GitHub Action PR-quality / AI-slop gate
# (pull_request_target). It is GHA-only — not treefmt, not prek, and not a
# local hook. Opt out with presets.ci.github_actions.anti-slop.enable = false
# and remove .github/workflows/pr-quality.yml.
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
    Generate .github/workflows/pr-quality.yml for peakoss/anti-slop (GHA-only
    PR quality / AI-slop checks). Complements hooks.yml prek; not a local hook.
  '';
  # Always available; presets.ci.github_actions.anti-slop.enable turns it off.
  when = _: true;

  module =
    { lib, ... }:
    {
      options.presets.ci.github_actions.anti-slop = {
        action = lib.mkOption {
          type = lib.types.str;
          default = "peakoss/anti-slop@v0.3.0";
          description = ''
            Marketplace Action pin (`owner/repo@tag`). Prefer an immutable
            release tag (e.g. v0.3.0) over the moving `v0` major line.
          '';
        };
        maxFailures = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 4;
          description = "anti-slop `max-failures` — how many check failures trigger failure actions.";
        };
        closePr = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "anti-slop `close-pr` — close the PR when max-failures is reached.";
        };
        exemptDraftPrs = lib.mkOption {
          type = lib.types.bool;
          # Draft agent / WIP PRs should not be auto-closed while iterating.
          default = true;
          description = "anti-slop `exempt-draft-prs` — skip all checks on draft PRs.";
        };
        extraWith = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = ''
            Extra `with:` inputs passed through to peakoss/anti-slop as raw YAML
            scalars (e.g. `{ "min-account-age" = "0"; }`). Same keys override
            the named options above.
          '';
          example = {
            require-description = "true";
            "min-account-age" = "0";
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
          maxFailures
          closePr
          exemptDraftPrs
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
