# YAML body for .github/workflows/pr-quality.yml (peakoss/anti-slop).
# Built as absolute lines (no indented ''-string) so with: keys stay aligned.
{ lib }:
let
  boolYaml = b: if b then "true" else "false";

  withLines =
    attrs:
    let
      names = lib.sort (a: b: a < b) (builtins.attrNames attrs);
    in
    map (name: "          ${name}: ${attrs.${name}}") names;
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
        "on:"
        "  pull_request_target:"
        "    types:"
        "      - opened"
        "      - reopened"
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
