# Render a MatrixPlan to GitHub Actions reusable-workflow YAML (test.yml shape).
{ lib }:
let
  matrixLib = import ../matrix.nix { inherit lib; };

  ghaOs =
    plan: cell:
    let
      profileId = cell.runner or null;
      bag =
        if profileId == null then
          null
        else
          matrixLib.requireProviderBag {
            inherit (plan) runnerProfiles strict;
            provider = "github_actions";
            inherit profileId;
          };
      runs = if bag == null then null else bag.runs-on or null;
    in
    if runs == null then
      cell.os or (throw "ci.backends.github_actions: cell missing runner profile and os")
    else if builtins.isList runs then
      # Single-label lists stay scalars so matrix.os is string-typed for
      # actionlint/cache keys; multi-label lists stay arrays for runs-on.
      if runs == [ ] then
        throw "ci.backends.github_actions: empty runs-on for profile '${toString profileId}'"
      else if lib.length runs == 1 then
        lib.head runs
      else
        runs
    else
      runs;

  # Fields that must not appear in strategy.matrix.include rows.
  metaKeys = [
    "runner"
    "optional"
    "providers"
    "secrets"
    "env"
    "command"
    "commandProfile"
  ];

  rowAttrs =
    plan: cell:
    {
      # When true, keep a bool optional flag for per-cell continue-on-error.
      keepOptional ? false,
    }:
    let
      os = ghaOs plan cell;
      strip = if keepOptional then lib.filter (k: k != "optional") metaKeys else metaKeys;
      rest = removeAttrs cell strip;
      withOpt =
        if keepOptional then
          rest
          // {
            optional = cell.optional or false;
          }
        else
          rest;
    in
    { inherit os; } // removeAttrs withOpt [ "os" ];

  matrixRow =
    attrs:
    let
      names = [ "os" ] ++ lib.filter (n: n != "os") (lib.attrNames attrs);
      # JSON encoding is YAML-safe for scalars (quotes, bools, numbers).
      fmt =
        name:
        let
          v = attrs.${name};
        in
        if builtins.isList v then
          "${name}: [${lib.concatStringsSep ", " (map builtins.toJSON v)}]"
        else
          "${name}: ${builtins.toJSON v}";
    in
    "        - ${fmt (lib.head names)}"
    + lib.concatMapStrings (name: "\n          ${fmt name}") (lib.tail names);

  padJob = text: "  " + lib.replaceStrings [ "\n" ] [ "\n  " ] (lib.removeSuffix "\n" text);

  # Emit run: as a block scalar when command is multiline (unless already `|…`).
  # JSON-quote single-line commands that contain `: ` (plain YAML mapping syntax).
  runYaml =
    command:
    if lib.hasPrefix "|" command then
      "run: ${command}"
    else if lib.hasInfix "\n" command then
      "run: |\n              ${lib.replaceStrings [ "\n" ] [ "\n              " ] command}"
    else if lib.hasInfix ": " command then
      "run: ${builtins.toJSON command}"
    else
      "run: ${command}";

  jobYaml =
    plan: job:
    let
      cells = job.cells or [ ];
      jobOptional = job.optional or false;
      anyCellOptional = lib.any (c: c.optional or false) cells;
      # Only emit optional in include rows when mixed required/optional cells.
      keepOptional = !jobOptional && anyCellOptional;
      rows = map (cell: rowAttrs plan cell { inherit keepOptional; }) cells;
      strategy = matrixLib.defaultStrategy // (job.strategy or { });
      inherit (strategy) failFast maxParallel;
      testRun =
        job.command or (throw "ci.backends.github_actions: job '${job.name or "?"}' missing command");
      maxParallelYaml = if maxParallel == null then "" else "\n    max-parallel: ${toString maxParallel}";
      # Job-level continue-on-error only for job.optional; otherwise per-cell via matrix.
      # Interpolated snippets skip Nix '' dedent; match post-dedent sibling indent (padJob +2).
      continueYaml =
        if jobOptional then
          "\n  continue-on-error: true"
        else if anyCellOptional then
          "\n  continue-on-error: \${{ matrix.optional }}"
        else
          "";
      # Human-readable job titles (from #124); stay local to this renderer.
      displayName =
        {
          python = "Python \${{ matrix.python_version }} (\${{ matrix.os }})";
          rust = "Rust \${{ matrix.channel }} \${{ matrix.version }} (\${{ matrix.os }})";
          go = "Go \${{ matrix.version }} (\${{ matrix.os }})";
          javascript = "JavaScript \${{ matrix.runtime }} \${{ matrix.version }} (\${{ matrix.os }})";
        }
        .${job.name} or "${job.name} (\${{ matrix.os }})";
    in
    ''
      ${job.name}:
        name: ${displayName}
        runs-on: ''${{ matrix.os }}${continueYaml}
        strategy:
          fail-fast: ${if failFast then "true" else "false"}${maxParallelYaml}
          matrix:
            include:
      ${lib.concatMapStringsSep "\n" matrixRow rows}
        steps:
          - uses: actions/checkout@v4
          - name: Own workspace under act
            if: ''${{ env.ACT }}
            run: |
              sudo mkdir -p /home/runner/.cache/nix /nix
              # Volume-mounted /nix is root-owned; single-user install-nix needs runner.
              # Nested act matrix cells share one /nix volume; recursive chown races with
              # concurrent nix creating/removing .lock files (ENOENT → non-zero under bash -e).
              sudo chown -R "$(id -u):$(id -g)" "''${GITHUB_WORKSPACE}" /home/runner/.cache
              if ! sudo chown -R "$(id -u):$(id -g)" /nix; then
                sudo chown "$(id -u):$(id -g)" /nix
              fi
          - uses: cachix/install-nix-action@v31
          - name: Restore Nix store
            id: nix-cache
            if: ''${{ !env.ACT }}
            uses: nix-community/cache-nix-action/restore@v7
            with:
              primary-key: nix-''${{ matrix.os }}-''${{ github.job }}-''${{ hashFiles('devenv.lock', 'devenv.yaml') }}
              restore-prefixes-first-match: nix-''${{ matrix.os }}-''${{ github.job }}-
          - uses: cachix/cachix-action@v16
            with:
              name: devenv
          - name: Install devenv
            run: |
              # Pin CLI to the locked modules rev (matches devenv.yaml require_version).
              rev="$(jq -r '.nodes.devenv.locked.rev' devenv.lock)"
              nix profile add "github:cachix/devenv/''${rev}"
          - name: Test
            ${runYaml testRun}
          - name: Save Nix store
            if: ''${{ always() && !env.ACT && steps.nix-cache.outputs.hit-primary-key != 'true' }}
            uses: nix-community/cache-nix-action/save@v7
            with:
              primary-key: ''${{ steps.nix-cache.outputs.primary-key }}
              gc-max-store-size-linux: 5G
    '';

  emptyWorkflow =
    plan:
    let
      # One matrix value per profile — do not flatten multi-label runs-on lists.
      preferred = [
        "ubuntu-24.04"
        "ubuntu-26.04"
      ];
      profileValues = lib.filter (v: v != null) (
        map (
          id:
          let
            bag = (plan.runnerProfiles.${id} or { }).providers.github_actions or { };
            runs = bag.runs-on or null;
          in
          if runs == null then
            null
          else if builtins.isList runs then
            if runs == [ ] then null else runs
          else
            [ runs ]
        ) (lib.attrNames plan.runnerProfiles)
      );
      # Unwrap single-label lists to scalars for the compact empty-matrix form.
      toMatrixValue = v: if builtins.isList v && lib.length v == 1 then lib.head v else v;
      raw = if profileValues == [ ] then preferred else map toMatrixValue profileValues;
      scalars = lib.filter builtins.isString raw;
      lists = lib.filter builtins.isList raw;
      orderedScalars =
        lib.filter (p: lib.elem p scalars) preferred ++ lib.filter (s: !(lib.elem s preferred)) scalars;
      ordered = orderedScalars ++ lists;
      hasMulti = lists != [ ];
      fmtOs =
        v: if builtins.isList v then "[${lib.concatStringsSep ", " (map builtins.toJSON v)}]" else v;
      matrixYaml =
        if hasMulti then
          "include:\n${
            lib.concatMapStringsSep "\n" (
              v: "            - os: ${if builtins.isList v then fmtOs v else builtins.toJSON v}"
            ) ordered
          }"
        else
          "os: [${lib.concatStringsSep ", " (map builtins.toJSON ordered)}]";
    in
    ''
      name: Test
      # TODO: cross-language version matrices (Rust × Python, …) are not supported.
      on:
        workflow_call:
      jobs:
        no-language-matrix:
          name: No language matrix (''${{ matrix.os }})
          strategy:
            fail-fast: false
            matrix:
              ${matrixYaml}
          runs-on: ''${{ matrix.os }}
          steps:
            - run: echo "No languages enabled; skipping per-version devenv test."
    '';

  # Render MatrixPlan → workflow YAML text (compatible with former versions.workflowText).
  render =
    plan:
    let
      jobs = plan.jobs or { };
      langOrder = [
        "python"
        "rust"
        "go"
        "javascript"
      ];
      ordered = lib.filter (n: (jobs.${n}.cells or [ ]) != [ ]) (
        lib.filter (n: jobs ? ${n}) langOrder
        ++ lib.filter (n: !(lib.elem n langOrder)) (lib.attrNames jobs)
      );
      rawJobs = lib.concatMapStrings (n: jobYaml plan jobs.${n}) ordered;
    in
    if rawJobs == "" then
      emptyWorkflow plan
    else
      ''
        name: Test
        # TODO: cross-language version matrices (Rust × Python, …) are not supported.
        # Each language is tested independently for its supported versions.
        on:
          workflow_call:
        # devenv test runs mise install; github: tools hit the GitHub API.
        env:
          MISE_GITHUB_TOKEN: ''${{ github.token }}
        jobs:
        ${padJob rawJobs}
      '';

in
{
  inherit
    matrixRow
    padJob
    jobYaml
    emptyWorkflow
    render
    ghaOs
    rowAttrs
    ;
}
