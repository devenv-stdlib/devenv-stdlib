# YAML body for .github/workflows/aletheore.yml (Aletheore/Aletheore).
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
  # cfg: {
  #   action, actionComment?, failOnNewSecrets, failOnNewVulnerabilities,
  #   failOnNewLayerViolations, full, postPrComment, extraWith
  # }
  workflowText =
    cfg:
    let
      named = {
        fail-on-new-secrets = boolYaml cfg.failOnNewSecrets;
        fail-on-new-vulnerabilities = boolYaml cfg.failOnNewVulnerabilities;
        fail-on-new-layer-violations = boolYaml cfg.failOnNewLayerViolations;
        full = boolYaml cfg.full;
        post-pr-comment = boolYaml cfg.postPrComment;
      };
      withAttrs = named // cfg.extraWith;
      comment = cfg.actionComment or "";
      usesLine =
        if comment == "" then "      - uses: ${cfg.action}" else "      - uses: ${cfg.action} # ${comment}";
    in
    lib.concatStringsSep "\n" (
      [
        "name: Aletheore"
        ""
        "permissions:"
        "  contents: read"
        "  issues: write"
        "  pull-requests: write"
        ""
        "on:"
        "  pull_request:"
        ""
        "jobs:"
        "  aletheore:"
        "    name: Security review (Aletheore)"
        "    runs-on: ubuntu-24.04"
        "    steps:"
        usesLine
        "        with:"
      ]
      ++ withLines withAttrs
      ++ [ "" ]
    );
}
