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

  # Monorepo-sensible product extensions when the option is left null.
  # Includes Nix + GHA YAML; excludes Markdown (docs-only diffs stay out of
  # product-code). Providing any list replaces the Action default set.
  defaultCodeFileExtensions = ''
    nix
    yml
    yaml
  '';

  # microsoft/PR-Metrics documented top-10-language defaults (pinned Action).
  # Used by the size gate when codeFileExtensions = "" omits the Action input.
  actionDefaultCodeFileExtensions = builtins.readFile ./action-default-code-file-extensions.list;
in
{
  # cfg: {
  #   action, actionComment?, checkoutAction, checkoutComment?, fetchDepth,
  #   baseSize, growthRate, testFactor,
  #   fileMatchingPatterns?, testMatchingPatterns?, codeFileExtensions?,
  #   continueOnError, rejectAboveMedium, exemptDraftPrs, extraWith
  # }
  inherit defaultCodeFileExtensions actionDefaultCodeFileExtensions;

  workflowText =
    cfg:
    let
      # null → monorepo default (nix/yml/yaml); "" → omit Action input; else override.
      effectiveExtensions =
        if (cfg.codeFileExtensions or null) == null then
          defaultCodeFileExtensions
        else
          cfg.codeFileExtensions;
      named = {
        base-size = toString cfg.baseSize;
        growth-rate = toString cfg.growthRate;
        test-factor = toString cfg.testFactor;
      }
      // optionalStr "file-matching-patterns" (cfg.fileMatchingPatterns or null)
      // optionalStr "test-matching-patterns" (cfg.testMatchingPatterns or null)
      // optionalStr "code-file-extensions" effectiveExtensions;
      withAttrs = named // cfg.extraWith;
      # Gate must match what the Action measures. When the Action input is omitted
      # (blank ""), use the pinned Action's documented defaults — do not count
      # every eligible file.
      gateExtensions =
        let
          resolved = withAttrs."code-file-extensions" or effectiveExtensions;
        in
        if resolved == null || resolved == "" then actionDefaultCodeFileExtensions else resolved;
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
      # Fail closed when the base commit is missing — never trust a title prefix
      # alone (fork authors can set XS/S/M while the token cannot rewrite it).
      # Extension filter matches the final `code-file-extensions` Action input.
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
            "          CODE_EXTS: ${builtins.toJSON gateExtensions}"
            "        run: |"
            "          set -euo pipefail"
            "          medium_max=$(awk -v b=\"\${BASE_SIZE}\" -v g=\"\${GROWTH_RATE}\" 'BEGIN { printf \"%.0f\", b * g * g }')"
            "          echo \"Medium ceiling (product-code lines): \${medium_max} (baseSize=\${BASE_SIZE} growthRate=\${GROWTH_RATE})\""
            "          if ! git rev-parse --verify \"\${BASE_SHA}^{commit}\" >/dev/null 2>&1; then"
            "            echo \"::error::Base SHA \${BASE_SHA} not available locally; refusing to determine PR size.\""
            "            exit 1"
            "          fi"
            "          # --numstat -z: NUL records; renames are added<TAB>deleted<TAB><NUL>old<NUL>new<NUL>"
            "          # (brace-form paths like tests/unit/{ => aspects}/foo break tab awk)."
            "          product=$(BASE_SHA=\"\${BASE_SHA}\" CODE_EXTS=\"\${CODE_EXTS}\" python3 -c '"
            "          import os, re, subprocess"
            "          base = os.environ[\"BASE_SHA\"]"
            "          exts = {e.strip().lstrip(\".\").lower() for e in os.environ.get(\"CODE_EXTS\", \"\").splitlines() if e.strip()}"
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
            "              fields = chunk.split(b\"\\t\", 2)"
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
            "              if exts:"
            "                  if \".\" not in path.rsplit(\"/\", 1)[-1]:"
            "                      continue"
            "                  if path.rsplit(\".\", 1)[-1].lower() not in exts:"
            "                      continue"
            "              product += int(added)"
            "          print(product)"
            "          ')"
            "          echo \"Product-code lines added (approx): \${product}\""
            "          if (( product >= medium_max )); then"
            "            echo \"::error::PR size exceeds medium (\${product} product lines >= \${medium_max}). Split the change, raise baseSize/growthRate, or set presets.ci.github_actions.pr-metrics.rejectAboveMedium = false.\""
            "            exit 1"
            "          fi"
            "          echo \"PR size within allowed maximum (medium).\""
            "          exit 0"
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
