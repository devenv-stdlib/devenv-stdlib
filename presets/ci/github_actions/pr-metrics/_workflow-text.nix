# YAML body for .github/workflows/pr-metrics.yml (microsoft/PR-Metrics).
# Built as absolute lines (no indented ''-string) so with: keys stay aligned.
{ lib }:
let
  withLines =
    attrs:
    let
      names = lib.sort (a: b: a < b) (builtins.attrNames attrs);
    in
    map (name: "          ${name}: ${attrs.${name}}") names;

  # Optional scalar → include only when non-null / non-empty.
  optionalStr = name: value: if value == null || value == "" then { } else { ${name} = value; };
in
{
  # cfg: {
  #   action, actionComment?, checkoutAction, fetchDepth,
  #   baseSize, growthRate, testFactor,
  #   fileMatchingPatterns?, testMatchingPatterns?, codeFileExtensions?,
  #   continueOnError, rejectAboveMedium, exemptDraftPrs, extraWith
  # }
  workflowText =
    cfg:
    let
      named = {
        base-size = toString cfg.baseSize;
        growth-rate = toString cfg.growthRate;
        test-factor = toString cfg.testFactor;
      }
      // optionalStr "file-matching-patterns" (cfg.fileMatchingPatterns or null)
      // optionalStr "test-matching-patterns" (cfg.testMatchingPatterns or null)
      // optionalStr "code-file-extensions" (cfg.codeFileExtensions or null);
      withAttrs = named // cfg.extraWith;
      comment = cfg.actionComment or "";
      usesLine =
        if comment == "" then "      - uses: ${cfg.action}" else "      - uses: ${cfg.action} # ${comment}";
      jobIf = if cfg.exemptDraftPrs then [ "    if: \${{ !github.event.pull_request.draft }}" ] else [ ];
      continueLine = if cfg.continueOnError then [ "        continue-on-error: true" ] else [ ];
      fetchDepthLine =
        if cfg.fetchDepth == null then [ ] else [ "          fetch-depth: ${toString cfg.fetchDepth}" ];

      # microsoft/PR-Metrics annotates titles as `<size><test?> ◾ <title>`
      # (sizes XS/S/M/L/XL/2XL…). It has no fail-on-size input, so this step
      # enforces "reject > medium" by reading the updated title.
      rejectSteps =
        if !cfg.rejectAboveMedium then
          [ ]
        else
          [
            "      - name: Reject oversized PRs"
            "        if: always()"
            "        env:"
            "          GH_TOKEN: \${{ secrets.GITHUB_TOKEN }}"
            "          PR_NUMBER: \${{ github.event.pull_request.number }}"
            "        run: |"
            "          set -euo pipefail"
            "          title=\"\$(gh api \"repos/\${GITHUB_REPOSITORY}/pulls/\${PR_NUMBER}\" --jq .title)\""
            "          echo \"PR title: \${title}\""
            "          # Allowed: XS / S / M (product lines < baseSize * growthRate^2)."
            "          if [[ \"\${title}\" =~ ^(XS|S|M)(✔|⚠️)?[[:space:]]*◾ ]]; then"
            "            echo \"PR size within allowed maximum (medium).\""
            "            exit 0"
            "          fi"
            "          if [[ \"\${title}\" =~ ^(L|[0-9]*XL)(✔|⚠️)?[[:space:]]*◾ ]]; then"
            "            echo \"::error::PR size exceeds medium (L/XL). Split the change, raise baseSize/growthRate, or set presets.ci.github_actions.pr-metrics.rejectAboveMedium = false.\""
            "            exit 1"
            "          fi"
            "          echo \"::error::Could not determine PR Metrics size prefix from title; refusing while rejectAboveMedium is enabled.\""
            "          exit 1"
          ];
    in
    lib.concatStringsSep "\n" (
      [
        "name: PR Metrics"
        ""
        "permissions:"
        "  contents: read"
        "  pull-requests: write"
        ""
        "on:"
        "  pull_request:"
        "    types:"
        "      - opened"
        "      - synchronize"
        "      - reopened"
        "      - ready_for_review"
        "      - edited"
        ""
        "jobs:"
        "  pr-metrics:"
      ]
      ++ jobIf
      ++ [
        "    runs-on: ubuntu-24.04"
        "    steps:"
        "      - uses: ${cfg.checkoutAction}"
      ]
      ++ (if fetchDepthLine == [ ] then [ ] else [ "        with:" ] ++ fetchDepthLine)
      ++ [
        usesLine
        "        name: PR Metrics"
        "        env:"
        "          PR_METRICS_ACCESS_TOKEN: \${{ secrets.GITHUB_TOKEN }}"
      ]
      ++ continueLine
      ++ [
        "        with:"
      ]
      ++ withLines withAttrs
      ++ rejectSteps
      ++ [ "" ]
    );
}
