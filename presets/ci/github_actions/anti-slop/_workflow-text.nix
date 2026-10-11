# YAML body for .github/workflows/pr-quality.yml (peakoss/anti-slop).
# Built as absolute lines (no indented ''-string) so with: keys stay aligned.
{ lib }:
let
  boolYaml = b: if b then "true" else "false";

  # Quote every with: value (JSON string → YAML double-quoted) so embedded
  # newlines (e.g. blocked-paths) stay a single scalar, not broken YAML lines.
  withLines =
    attrs:
    let
      names = lib.sort (a: b: a < b) (builtins.attrNames attrs);
    in
    map (name: "          ${name}: ${builtins.toJSON attrs.${name}}") names;
in
{
  # cfg: { action, actionComment?, maxFailures, closePr, exemptDraftPrs,
  #         exemptAuthorAssociation, requireCommitAuthorMatch,
  #         requireMaintainerCanModify, extraWith }
  workflowText =
    cfg:
    let
      named = {
        max-failures = toString cfg.maxFailures;
        close-pr = boolYaml cfg.closePr;
        exempt-draft-prs = boolYaml cfg.exemptDraftPrs;
        # Marketplace default is OWNER,MEMBER,COLLABORATOR; empty = scan everyone.
        exempt-author-association = cfg.exemptAuthorAssociation;
        require-commit-author-match = boolYaml cfg.requireCommitAuthorMatch;
        require-maintainer-can-modify = boolYaml cfg.requireMaintainerCanModify;
      };
      withAttrs = named // cfg.extraWith;
      comment = cfg.actionComment or "";
      usesLine =
        if comment == "" then "      - uses: ${cfg.action}" else "      - uses: ${cfg.action} # ${comment}";
    in
    lib.concatStringsSep "\n" (
      [
        "name: PR Quality"
        ""
        "permissions:"
        "  contents: read"
        "  issues: read"
        "  pull-requests: write"
        ""
        # pull_request (not pull_request_target): GHA loads
        # pull_request_target workflows from the repo *default* branch, so a
        # PR that introduces pr-quality.yml would never run the check on
        # itself. Same-repo dogfood matches aletheore.yml; still no checkout
        # of the PR head (action uses the GitHub API only).
        # Include ready_for_review: anti-slop honors exempt-draft-prs from the
        # event payload only; re-runs keep a frozen draft-era payload, so
        # draft→ready must fire a new run (not a re-run of synchronize).
        "on:"
        "  pull_request:"
        "    types:"
        "      - opened"
        "      - synchronize"
        "      - reopened"
        "      - ready_for_review"
        ""
        "jobs:"
        "  anti-slop:"
        "    name: PR quality (anti-slop)"
        "    runs-on: ubuntu-24.04"
        "    steps:"
        usesLine
        "        with:"
      ]
      ++ withLines withAttrs
      ++ [ "" ]
    );
}
