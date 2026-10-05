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
  # cfg: { action, actionComment?, maxFailures, closePr, exemptDraftPrs, extraWith }
  workflowText =
    cfg:
    let
      named = {
        max-failures = toString cfg.maxFailures;
        close-pr = boolYaml cfg.closePr;
        exempt-draft-prs = boolYaml cfg.exemptDraftPrs;
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
        # pull_request (not pull_request_target): GHA only loads
        # pull_request_target workflows from the *base* branch, so a PR that
        # introduces pr-quality.yml would never run the check on itself.
        # Same-repo dogfood matches aletheore.yml; still no checkout of the
        # PR head (action uses the GitHub API only).
        "on:"
        "  pull_request:"
        ""
        "jobs:"
        "  anti-slop:"
        "    runs-on: ubuntu-24.04"
        "    steps:"
        usesLine
        "        with:"
      ]
      ++ withLines withAttrs
      ++ [ "" ]
    );
}
