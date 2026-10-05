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
      lib.head runs
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
      # When true, keep a string optional flag for per-cell continue-on-error.
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
            optional = if cell.optional or false then "true" else "false";
          }
        else
          rest;
    in
    { inherit os; } // removeAttrs withOpt [ "os" ];

  matrixRow =
    attrs:
    let
      names = [ "os" ] ++ lib.filter (n: n != "os") (lib.attrNames attrs);
      fmt = name: "${name}: \"${toString attrs.${name}}\"";
    in
    "        - ${fmt (lib.head names)}"
    + lib.concatMapStrings (name: "\n          ${fmt name}") (lib.tail names);

  padJob = text: "  " + lib.replaceStrings [ "\n" ] [ "\n  " ] (lib.removeSuffix "\n" text);

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
      maxParallelYaml =
        if maxParallel == null then "" else "\n      max-parallel: ${toString maxParallel}";
      # Job-level continue-on-error only for job.optional; otherwise per-cell via matrix.
      continueYaml =
        if jobOptional then
          "\n    continue-on-error: true"
        else if anyCellOptional then
          "\n    continue-on-error: \${{ matrix.optional == 'true' }}"
        else
          "";
    in
    ''
      ${job.name}:
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
            run: ${testRun}
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
      runners = lib.unique (
        lib.concatMap (
          id:
          let
            bag = (plan.runnerProfiles.${id} or { }).providers.github_actions or { };
            runs = bag.runs-on or [ ];
          in
          if builtins.isList runs then runs else lib.optional (runs != null) runs
        ) (lib.attrNames plan.runnerProfiles)
      );
      # Keep previous-then-current order from default profiles when possible.
      preferred = [
        "ubuntu-24.04"
        "ubuntu-26.04"
      ];
      osList =
        if runners == [ ] then
          preferred
        else
          lib.filter (r: lib.elem r runners) preferred ++ lib.filter (r: !(lib.elem r preferred)) runners;
    in
    ''
      name: Test
      # TODO: cross-language version matrices (Rust × Python, …) are not supported.
      on:
        workflow_call:
      jobs:
        no-language-matrix:
          strategy:
            fail-fast: false
            matrix:
              os: [${lib.concatStringsSep ", " osList}]
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
