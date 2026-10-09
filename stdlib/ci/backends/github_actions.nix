# Render a MatrixPlan to GitHub Actions reusable-workflow YAML (test.yml shape).
# Optionally merges an AttachmentPlan into step slots around the primary command.
{ lib }:
let
  matrixLib = import ../matrix.nix { inherit lib; };
  attachmentsLib = import ../attachments.nix { inherit lib; };

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
  # Always JSON-quote other single-line commands so YAML `#` / `: ` cannot corrupt them.
  runYaml =
    command:
    if lib.hasPrefix "|" command then
      "run: ${command}"
    else if lib.hasInfix "\n" command then
      "run: |\n              ${lib.replaceStrings [ "\n" ] [ "\n              " ] command}"
    else
      "run: ${builtins.toJSON command}";

  # YAML-safe scalar (same toJSON approach as matrixRow).
  yamlScalar =
    raw:
    if builtins.isBool raw then
      (if raw then "true" else "false")
    else if builtins.isInt raw then
      toString raw
    else
      builtins.toJSON raw;

  # Only with:/env: values expand `secret:NAME`; run/uses/if never do.
  secretOrScalar =
    raw:
    if builtins.isString raw && lib.hasPrefix "secret:" raw then
      let
        name = lib.removePrefix "secret:" raw;
      in
      if builtins.match "[A-Za-z_][A-Za-z0-9_]*" name == null then
        throw "ci.backends.github_actions: invalid secret name in '${raw}'"
      else
        "\${{ secrets.${name} }}"
    else
      yamlScalar raw;

  # Format a with:/env: map. Secret *names* become ${{ secrets.NAME }} only.
  kvBlock =
    indent: attrs:
    lib.concatMapStrings (name: "\n${indent}${name}: ${secretOrScalar attrs.${name}}") (
      lib.attrNames attrs
    );

  # Attachment run: at post-dedent indent; single-line values are YAML-safe scalars.
  attachRunYaml =
    command:
    if lib.hasPrefix "|" command then
      "run: ${command}"
    else if lib.hasInfix "\n" command then
      "run: |\n        ${lib.replaceStrings [ "\n" ] [ "\n        " ] command}"
    else
      "run: ${yamlScalar command}";

  # One GHA step fragment at post-dedent indent (4 spaces before `-`).
  # padJob then adds +2. Secrets on the provider bag → env: NAME: ${{ secrets.NAME }}.
  attachmentStepYaml =
    attachment:
    let
      bag = attachment.providers.github_actions or { };
      stepName = bag.name or attachment.id or "attachment";
      slot = bag.slot or "pre-command";
      secrets = bag.secrets or [ ];
      withAttrs = bag."with" or { };
      envAttrs =
        (bag.env or { })
        // lib.listToAttrs (
          map (s: {
            name = s;
            value = "secret:${s}";
          }) secrets
        );
      # bag."if" is a bare GHA expression (no ${{ }}). Custom always-slot
      # conditions must keep always() — bare if gets an implicit success().
      ifClause =
        let
          custom = bag."if" or null;
        in
        if custom != null then
          if slot == "always" then "always() && (${custom})" else custom
        else if slot == "always" then
          "\${{ always() }}"
        else
          null;
      uses = bag.uses or null;
      run = bag.run or null;
      header =
        "    - name: ${yamlScalar stepName}"
        + (if ifClause == null then "" else "\n      if: ${yamlScalar ifClause}")
        + (
          if uses != null then
            "\n      uses: ${yamlScalar uses}"
          else if run != null then
            "\n      ${attachRunYaml run}"
          else
            throw "ci.backends.github_actions: attachment '${stepName}' needs uses or run"
        );
      withBlock = if withAttrs == { } then "" else "\n      with:" + kvBlock "        " withAttrs;
      envBlock = if envAttrs == { } then "" else "\n      env:" + kvBlock "        " envAttrs;
      # Explicit 4-space step indent (do not use '' strings — Nix strips common indent).
      artifactSteps = lib.concatMapStrings (
        art:
        let
          artName = art.id or art.name or "artifact";
          path = art.path or (throw "ci.backends.github_actions: artifact missing path");
        in
        "    - name: ${yamlScalar "Upload ${artName}"}\n"
        + "      if: \${{ always() }}\n"
        + "      uses: actions/upload-artifact@v4\n"
        + "      with:\n"
        # upload-artifact@v4 names must be unique across the whole run.
        + "        name: ${yamlScalar "${artName}-\${{ github.job }}-\${{ strategy.job-index }}"}\n"
        + "        path: ${yamlScalar path}\n"
      ) (attachment.artifacts or [ ]);
    in
    header + withBlock + envBlock + "\n" + artifactSteps;

  slotStepsYaml = slotted: slot: lib.concatMapStrings attachmentStepYaml (slotted.${slot} or [ ]);

  # Standalone helper for host workflows — same step shape, keyed by slot.
  renderAttachments =
    attachmentPlan:
    {
      language ? null,
      provider ? "github_actions",
      forge ? null,
    }:
    let
      ctx = {
        inherit
          provider
          language
          forge
          ;
      };
      slotted = attachmentsLib.bySlot attachmentPlan ctx;
    in
    lib.listToAttrs (
      map (slot: {
        name = slot;
        value = slotStepsYaml slotted slot;
      }) attachmentsLib.slots
    );

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
      attachmentPlan = plan.attachments or attachmentsLib.emptyPlan;
      slotted = attachmentsLib.bySlot attachmentPlan {
        provider = "github_actions";
        language = job.name or null;
      };
      preToolchain = slotStepsYaml slotted "pre-toolchain";
      preCommand = slotStepsYaml slotted "pre-command";
      postSlots = slotStepsYaml slotted "post-command";
      alwaysSlots = slotStepsYaml slotted "always";
      # Marker lines sit at step indent so empty-plan replace drops them with no
      # extra blank lines (byte-stable vs MatrixPlan phase-1 jobYaml).
      # pre-toolchain: after checkout/act, before nix/devenv toolchain bootstrap.
      # pre-command: after Install devenv (toolchain on PATH), before Test.
      body = ''
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
            __ATTACH_PRE_TOOLCHAIN__
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
            __ATTACH_PRE_COMMAND__
            - name: Test
              ${runYaml testRun}
            __ATTACH_POST__
            - name: Save Nix store
              if: ''${{ always() && !env.ACT && steps.nix-cache.outputs.hit-primary-key != 'true' }}
              uses: nix-community/cache-nix-action/save@v7
              with:
                primary-key: ''${{ steps.nix-cache.outputs.primary-key }}
                gc-max-store-size-linux: 5G
            __ATTACH_ALWAYS__
      '';
    in
    # Body min-indent is 8 spaces (`        ${job.name}`), so markers dedent to
    # 4 spaces — same as post-dedent step list items.
    lib.replaceStrings
      [
        "    __ATTACH_PRE_TOOLCHAIN__\n"
        "    __ATTACH_PRE_COMMAND__\n"
        "    __ATTACH_POST__\n"
        "    __ATTACH_ALWAYS__\n"
      ]
      [
        preToolchain
        preCommand
        postSlots
        alwaysSlots
      ]
      body;

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

  # Unpadded YAML for every job with cells: languages first, then other jobs by name.
  jobsYaml =
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
    in
    lib.concatMapStrings (n: jobYaml plan jobs.${n}) ordered;

  # Render MatrixPlan → workflow YAML text.
  render =
    plan:
    let
      rawJobs = jobsYaml plan;
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
    jobsYaml
    emptyWorkflow
    render
    ghaOs
    rowAttrs
    attachmentStepYaml
    renderAttachments
    yamlScalar
    ;
}
