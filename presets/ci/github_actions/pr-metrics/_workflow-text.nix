# YAML body for .github/workflows/pr-metrics.yml (microsoft/PR-Metrics).
# Built as absolute lines (no indented ''-string) so with: keys stay aligned.
{ lib }:
let
  withLines =
    attrs:
    let
      names = lib.sort (a: b: a < b) (builtins.attrNames attrs);
    in
    # Quote every value as a JSON string so YAML aliases (`*.cs`) and
    # embedded newlines stay one scalar (GHA `with:` values are strings).
    map (name: "          ${name}: ${builtins.toJSON attrs.${name}}") names;

  # Optional scalar → include only when non-null / non-empty.
  optionalStr = name: value: if value == null || value == "" then { } else { ${name} = value; };

  usesWithComment =
    action: comment:
    if comment == "" then "      - uses: ${action}" else "      - uses: ${action} # ${comment}";
in
{
  # cfg: {
  #   action, actionComment?, checkoutAction, checkoutComment?, fetchDepth,
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
      actionUses = usesWithComment cfg.action (cfg.actionComment or "");
      checkoutUses = usesWithComment cfg.checkoutAction (cfg.checkoutComment or "");
      jobIf = if cfg.exemptDraftPrs then [ "    if: \${{ !github.event.pull_request.draft }}" ] else [ ];
      continueLine = if cfg.continueOnError then [ "        continue-on-error: true" ] else [ ];

      checkoutWith = [
        "        with:"
      ]
      ++ (if cfg.fetchDepth == null then [ ] else [ "          fetch-depth: ${toString cfg.fetchDepth}" ])
      ++ [ "          persist-credentials: false" ];

      # Reject > medium without relying on a title write. Fork pull_request runs
      # get a read-only GITHUB_TOKEN by default, so microsoft/PR-Metrics may not
      # be able to prefix the title; compute product-code adds from git instead.
      # Title format (v1.7.18 loc): `XS✔ ◾ title` — also accept README `✔️` / `▪️`.
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
            "          BASE_SHA: \${{ github.event.pull_request.base.sha }}"
            "          BASE_SIZE: ${toString cfg.baseSize}"
            "          GROWTH_RATE: ${toString cfg.growthRate}"
            "        run: |"
            "          set -euo pipefail"
            "          medium_max=$(awk -v b=\"\${BASE_SIZE}\" -v g=\"\${GROWTH_RATE}\" 'BEGIN { printf \"%.0f\", b * g * g }')"
            "          echo \"Medium ceiling (product-code lines): \${medium_max} (baseSize=\${BASE_SIZE} growthRate=\${GROWTH_RATE})\""
            "          product=\"\""
            "          if git rev-parse --verify \"\${BASE_SHA}^{commit}\" >/dev/null 2>&1; then"
            "            # --numstat -z: NUL records; renames are added<TAB>deleted<TAB><NUL>old<NUL>new<NUL>"
            "            # (brace-form paths like tests/unit/{ => aspects}/foo break tab awk)."
            "            product=$(BASE_SHA=\"\${BASE_SHA}\" python3 -c '"
            "          import os, re, subprocess"
            "          base = os.environ[\"BASE_SHA\"]"
            "          raw = subprocess.check_output([\"git\", \"diff\", \"--numstat\", \"-z\", f\"{base}...HEAD\"])"
            "          parts = raw.split(b\"\\0\")"
            "          product = 0"
            "          i = 0"
            "          test_dir = re.compile(r\"(^|/)(tests?|__tests__|spec)/\")"
            "          test_file = re.compile(r\"(^|[/_.-])[Tt]ests?([_.-]|\\.|$)|\\.[Ss]pec\\.|\\.[Tt]est\\.\")"
            "          lock = re.compile(r\"(^|/)package-lock\\.json$\")"
            "          while i < len(parts):"
            "              chunk = parts[i]"
            "              if not chunk:"
            "                  i += 1"
            "                  continue"
            "              fields = chunk.split(b\"\\t\")"
            "              if len(fields) < 2:"
            "                  i += 1"
            "                  continue"
            "              added = fields[0]"
            "              if len(fields) >= 3 and fields[2] != b\"\":"
            "                  path = fields[2].decode(errors=\"replace\")"
            "                  i += 1"
            "              else:"
            "                  if i + 2 >= len(parts):"
            "                      break"
            "                  path = parts[i + 2].decode(errors=\"replace\")"
            "                  i += 3"
            "              if added == b\"-\":"
            "                  continue"
            "              if lock.search(path) or test_dir.search(path) or test_file.search(path):"
            "                  continue"
            "              product += int(added)"
            "          print(product)"
            "          ')"
            "            echo \"Product-code lines added (approx): \${product}\""
            "          else"
            "            echo \"::warning::Base SHA \${BASE_SHA} not available locally; falling back to title prefix.\""
            "          fi"
            "          if [[ -n \"\${product}\" ]]; then"
            "            if (( product >= medium_max )); then"
            "              echo \"::error::PR size exceeds medium (\${product} product lines >= \${medium_max}). Split the change, raise baseSize/growthRate, or set presets.ci.github_actions.pr-metrics.rejectAboveMedium = false.\""
            "              exit 1"
            "            fi"
            "            echo \"PR size within allowed maximum (medium).\""
            "            exit 0"
            "          fi"
            "          title=$(gh api \"repos/\${GITHUB_REPOSITORY}/pulls/\${PR_NUMBER}\" --jq .title)"
            "          echo \"PR title: \${title}\""
            "          if [[ \"\${title}\" =~ ^(XS|S|M)[[:space:]]*(✔|✔️|⚠️)?[[:space:]]*(◾|▪️) ]]; then"
            "            echo \"PR size within allowed maximum (medium) via title prefix.\""
            "            exit 0"
            "          fi"
            "          if [[ \"\${title}\" =~ ^(L|[0-9]*XL)[[:space:]]*(✔|✔️|⚠️)?[[:space:]]*(◾|▪️) ]]; then"
            "            echo \"::error::PR size exceeds medium (L/XL title prefix). Split the change, raise baseSize/growthRate, or set presets.ci.github_actions.pr-metrics.rejectAboveMedium = false.\""
            "            exit 1"
            "          fi"
            "          echo \"::error::Could not determine PR size (no git base diff and unrecognized title prefix); refusing while rejectAboveMedium is enabled.\""
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
        "    name: PR size (pr-metrics)"
        "    runs-on: ubuntu-24.04"
        "    steps:"
        checkoutUses
      ]
      ++ checkoutWith
      ++ [
        actionUses
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
