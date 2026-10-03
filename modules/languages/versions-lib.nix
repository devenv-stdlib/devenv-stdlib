{
  lib,
  catalog ? { },
}:
let
  emptyPolicy = {
    min = null;
    max = null;
    versions = [ ];
    unsupported = [ ];
  };
in
rec {
  jsRuntimes = [
    "nodejs"
    "bun"
    "deno"
  ];

  pythonImpls = [
    "cpython"
    "pypy"
  ];

  rustChannels = [
    "stable"
    "beta"
    "nightly"
  ];

  rustEditions = [
    "2015"
    "2018"
    "2021"
    "2024"
  ];

  rustEditionSince = {
    "2015" = "1.0.0";
    "2018" = "1.31.0";
    "2021" = "1.56.0";
    "2024" = "1.85.0";
  };

  rustfmtEditionArgs =
    edition:
    lib.optionals (edition != null) [
      "--edition"
      edition
    ];

  rustEditionTooOld =
    edition: version:
    edition != null
    && version != null
    && lib.hasAttr edition rustEditionSince
    && lib.versionOlder version rustEditionSince.${edition};

  rustEditionBoundProblem =
    label: edition: version:
    lib.optional (rustEditionTooOld edition version) "supported.rust.edition ${edition} requires rustc ${rustEditionSince.${edition}} or newer (${label} is ${version})";

  # Host policy: the current Ubuntu LTS and the previous one.
  ubuntuLts = {
    previous = "24.04";
    current = "26.04";
  };

  ubuntuRunners = [
    "ubuntu-${ubuntuLts.previous}"
    "ubuntu-${ubuntuLts.current}"
  ];

  crossOs = rows: lib.concatMap (os: map (row: { inherit os; } // row) rows) ubuntuRunners;

  inherit emptyPolicy;

  emptyPython = emptyPolicy // {
    implementations = [ "cpython" ];
  };

  emptyRust = emptyPolicy // {
    channels = [ "stable" ];
    edition = null;
  };

  emptyGo = emptyPolicy;

  emptyJavascript = {
    runtimes = [ ];
    nodejs = emptyPolicy;
    bun = emptyPolicy;
    deno = emptyPolicy;
  };

  parseVersion = v: map lib.toInt (lib.splitString "." v);

  formatVersion = components: lib.concatMapStringsSep "." toString components;

  # Inclusive range by stepping the single component that changes (1.80.0–1.85.0
  # → 1.80.0, 1.81.0, …, 1.85.0). Multiple differing components cannot be
  # inferred; callers should set `versions` or report a problem.
  enumerateRange =
    min: max:
    if max == null || max == min then
      {
        ok = true;
        versions = [ min ];
      }
    else
      let
        a = parseVersion min;
        b = parseVersion max;
      in
      if lib.length a != lib.length b then
        {
          ok = false;
          versions = [
            min
            max
          ];
        }
      else
        let
          diffs = lib.filter (i: lib.elemAt a i != lib.elemAt b i) (lib.range 0 (lib.length a - 1));
        in
        if diffs == [ ] then
          {
            ok = true;
            versions = [ min ];
          }
        else if lib.length diffs != 1 then
          {
            ok = false;
            versions = [
              min
              max
            ];
          }
        else
          let
            i = lib.head diffs;
            from = lib.elemAt a i;
            to = lib.elemAt b i;
            nums = if from <= to then lib.range from to else [ ];
            mk = x: formatVersion (lib.take i a ++ [ x ] ++ lib.drop (i + 1) a);
          in
          {
            ok = true;
            versions = map mk nums;
          };

  rangeStepOk =
    policy:
    policy.min == null
    || policy.max == null
    || policy.versions != [ ]
    || (enumerateRange policy.min policy.max).ok;

  hasPatch = v: lib.length (parseVersion v) >= 3;

  omitsPatch = v: v != null && !hasPatch v;

  matchesCycle =
    version: cycle:
    version == cycle || lib.hasPrefix (cycle + ".") version || lib.hasPrefix (version + ".") cycle;

  findRelease =
    product: version:
    let
      rels = (catalog.${product} or { }).releases or [ ];
      hits = lib.filter (r: matchesCycle version r.cycle) rels;
    in
    if hits == [ ] then
      null
    else
      lib.foldl' (
        best: r: if lib.stringLength r.cycle > lib.stringLength best.cycle then r else best
      ) (lib.head hits) (lib.tail hits);

  catalogActive =
    product: policy:
    lib.hasAttr product catalog
    && omitsPatch policy.min
    && (policy.max == null || omitsPatch policy.max);

  releaseUnsupported =
    policy: r: lib.elem r.latest policy.unsupported || lib.elem r.cycle policy.unsupported;

  resolveFromCatalog =
    product: policy:
    let
      rels = (catalog.${product} or { }).releases or [ ];
      inBounds =
        r:
        if policy.max == null then
          matchesCycle policy.min r.cycle
        else
          lib.versionAtLeast r.cycle policy.min && lib.versionAtLeast policy.max r.cycle;
      picked = lib.filter (r: inBounds r && !r.eol && !releaseUnsupported policy r) rels;
    in
    map (r: r.latest) (lib.sort (a: b: lib.versionOlder a.cycle b.cycle) picked);

  expandExplicit =
    product: policy:
    lib.filter (v: v != null) (
      map (
        v:
        if lib.hasAttr product catalog && !hasPatch v then
          let
            r = findRelease product v;
          in
          if r == null || r.eol || releaseUnsupported policy r then null else r.latest
        else if lib.elem v policy.unsupported then
          null
        else
          v
      ) policy.versions
    );

  # Step min..max when the patch is specified (1.80.0–1.85.0). When it is
  # omitted (3.12, 22), use each catalog cycle's latest patch and drop EOL.
  resolvedVersions =
    policy:
    let
      raw =
        if policy.min == null then
          [ ]
        else if policy.versions != [ ] then
          policy.versions
        else
          (enumerateRange policy.min policy.max).versions;
    in
    lib.filter (v: !(lib.elem v policy.unsupported)) raw;

  resolvedVersionsFor =
    product: policy:
    if policy.min == null then
      [ ]
    else if policy.versions != [ ] then
      if lib.hasAttr product catalog then expandExplicit product policy else resolvedVersions policy
    else if catalogActive product policy then
      resolveFromCatalog product policy
    else
      resolvedVersions policy;

  cycleLabel =
    v:
    let
      parts = parseVersion v;
    in
    if lib.length parts >= 2 then formatVersion (lib.take 2 parts) else v;

  inRange =
    policy: v:
    lib.versionAtLeast v policy.min
    && (policy.max == null || lib.versionAtLeast policy.max v || matchesCycle v policy.max)
    && !(lib.elem v policy.unsupported);

  boundProblems =
    product: label: pol:
    let
      active = catalogActive product pol;
      rmin = if active && pol.min != null then findRelease product pol.min else null;
      rmax = if active && pol.max != null then findRelease product pol.max else null;
      resolved = resolvedVersionsFor product pol;
    in
    lib.optionals (pol.min != null) [
      (lib.optional (active && rmin == null) "${label}.min (${pol.min}) is not in the toolchain catalog")
      (lib.optional (rmin != null && rmin.eol) "${label}.min (${pol.min}) has reached end of life")
      (lib.optional (
        active && pol.max != null && rmax == null
      ) "${label}.max (${pol.max}) is not in the toolchain catalog")
      (lib.optional (rmax != null && rmax.eol) "${label}.max (${pol.max}) has reached end of life")
      (lib.optional (
        !active && !rangeStepOk pol
      ) "${label}.min and max must differ in exactly one component (or set versions explicitly)")
      (lib.optional (
        !(lib.all (inRange pol) resolved)
      ) "${label}.versions must sit between min and max and omit unsupported")
      (lib.optional (
        resolved == [ ] && rmin != null && !rmin.eol
      ) "${label} has no supported non-EOL versions between min and max")
    ];

  problems =
    {
      pythonOn ? false,
      rustOn ? false,
      goOn ? false,
      javascriptOn ? false,
      python ? emptyPython,
      rust ? emptyRust,
      go ? emptyGo,
      javascript ? emptyJavascript,
    }:
    lib.flatten [
      (lib.optional (
        pythonOn && python.min == null
      ) "languages.python.enable requires supported.python.min")
      (lib.optional (
        pythonOn && python.min != null && lib.versionOlder python.min "3"
      ) "supported.python.min must be Python 3 or above (got ${python.min})")
      (lib.optional (
        pythonOn && python.max != null && lib.versionOlder python.max "3"
      ) "supported.python.max must be Python 3 or above (got ${python.max})")
      (lib.optional (
        pythonOn && python.max != null && python.min != null && lib.versionOlder python.max python.min
      ) "supported.python.max (${python.max}) is older than min (${python.min})")
      (lib.optional (
        pythonOn && python.implementations == [ ]
      ) "supported.python.implementations must include cpython and/or pypy")
      (lib.optionals pythonOn (boundProblems "python" "supported.python" python))

      (lib.optional (rustOn && rust.min == null) "languages.rust.enable requires supported.rust.min")
      (lib.optional (
        rustOn && rust.max != null && rust.min != null && lib.versionOlder rust.max rust.min
      ) "supported.rust.max (${rust.max}) is older than min (${rust.min})")
      (lib.optionals rustOn (
        rustEditionBoundProblem "min" rust.edition rust.min
        ++ rustEditionBoundProblem "max" rust.edition rust.max
      ))
      (lib.optional (
        rustOn && !(lib.elem "stable" rust.channels)
      ) "supported.rust.channels must include stable")
      (lib.optionals rustOn (boundProblems "rust" "supported.rust" rust))

      (lib.optional (goOn && go.min == null) "languages.go.enable requires supported.go.min")
      (lib.optional (
        goOn && go.max != null && go.min != null && lib.versionOlder go.max go.min
      ) "supported.go.max (${go.max}) is older than min (${go.min})")
      (lib.optionals goOn (boundProblems "go" "supported.go" go))

      (lib.optional (javascriptOn && javascript.runtimes == [ ])
        "languages.javascript or languages.typescript requires supported.javascript.runtimes (nodejs, bun, deno)"
      )
      (lib.concatMap (
        runtime:
        let
          pol = javascript.${runtime};
          label = "supported.javascript.${runtime}";
        in
        lib.optionals (javascriptOn && lib.elem runtime javascript.runtimes) (
          [
            (lib.optional (pol.min == null) "${label}.min is required when ${runtime} is selected")
            (lib.optional (
              pol.max != null && pol.min != null && lib.versionOlder pol.max pol.min
            ) "${label}.max (${pol.max}) is older than min (${pol.min})")
          ]
          ++ boundProblems runtime label pol
        )
      ) jsRuntimes)
    ];

  matrixRow =
    attrs:
    let
      names = [ "os" ] ++ lib.filter (n: n != "os") (lib.attrNames attrs);
      fmt = name: "${name}: \"${toString attrs.${name}}\"";
    in
    "        - ${fmt (lib.head names)}"
    + lib.concatMapStrings (name: "\n          ${fmt name}") (lib.tail names);

  jobYaml = name: rows: testRun: ''
    ${name}:
      runs-on: ''${{ matrix.os }}
      strategy:
        fail-fast: false
        matrix:
          include:
    ${lib.concatMapStringsSep "\n" matrixRow (crossOs rows)}
      steps:
        - uses: actions/checkout@v4
        - name: Own workspace under act
          if: ''${{ env.ACT }}
          run: |
            sudo mkdir -p /home/runner/.cache/nix /nix
            # Volume-mounted /nix is root-owned; single-user install-nix needs runner.
            sudo chown -R "$(id -u):$(id -g)" "''${GITHUB_WORKSPACE}" /home/runner/.cache /nix
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
            # Pin CLI to the locked modules rev (devenv.yaml require_version: true).
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

  nodePackage = version: "nodejs_${lib.versions.major version}";

  withPolicyMin = min: map (row: row // { policy_min = min; });

  pythonRows =
    py:
    withPolicyMin py.min (
      lib.concatMap (
        impl:
        map (version: {
          implementation = impl;
          inherit version;
          python_version = if impl == "pypy" then "pypy${cycleLabel version}" else version;
        }) (resolvedVersionsFor "python" py)
      ) py.implementations
    );

  rustRows =
    rs:
    withPolicyMin rs.min (
      map (version: {
        channel = "stable";
        inherit version;
      }) (resolvedVersionsFor "rust" rs)
      ++ map (channel: {
        inherit channel;
        version = "latest";
      }) (lib.filter (c: c != "stable") rs.channels)
    );

  goRows =
    go: withPolicyMin go.min (map (version: { inherit version; }) (resolvedVersionsFor "go" go));

  javascriptRows =
    js:
    lib.concatMap (
      runtime:
      withPolicyMin js.${runtime}.min (
        map (version: {
          inherit runtime version;
          pkg = if runtime == "nodejs" then nodePackage version else "";
        }) (resolvedVersionsFor runtime js.${runtime})
      )
    ) js.runtimes;

  padJob = text: "  " + lib.replaceStrings [ "\n" ] [ "\n  " ] (lib.removeSuffix "\n" text);

  languageJobs =
    {
      pythonOn ? false,
      rustOn ? false,
      goOn ? false,
      javascriptOn ? false,
      python ? emptyPython,
      rust ? emptyRust,
      go ? emptyGo,
      javascript ? emptyJavascript,
    }:
    let
      rawJobs = lib.concatStrings (
        lib.optional pythonOn (
          jobYaml "python" (pythonRows python)
            "devenv --option languages.python.enable:bool true --option languages.python.version:string \${{ matrix.python_version }} --option supported.python.min:string \${{ matrix.policy_min }} test"
        )
        ++ lib.optional rustOn (
          jobYaml "rust" (rustRows rust)
            "devenv --option languages.rust.enable:bool true --option languages.rust.channel:string \${{ matrix.channel }} --option languages.rust.version:string \${{ matrix.version }} --option supported.rust.min:string \${{ matrix.policy_min }} test"
        )
        ++ lib.optional goOn (
          jobYaml "go" (goRows go)
            "devenv --option languages.go.enable:bool true --option languages.go.version:string \${{ matrix.version }} --option supported.go.min:string \${{ matrix.policy_min }} test"
        )
        ++ lib.optional javascriptOn (
          jobYaml "javascript" (javascriptRows javascript) ''
            |
                          if [ "''${{ matrix.runtime }}" = nodejs ]; then
                            devenv --option languages.javascript.enable:bool true --option languages.javascript.package:pkg ''${{ matrix.pkg }} test
                          elif [ "''${{ matrix.runtime }}" = bun ]; then
                            devenv --option languages.javascript.enable:bool true --option languages.javascript.bun.enable:bool true test
                          else
                            devenv --option languages.javascript.enable:bool true --option languages.deno.enable:bool true test
                          fi
          ''
        )
      );
    in
    if rawJobs == "" then "" else padJob rawJobs;

  workflowText =
    args:
    let
      jobs = languageJobs args;
    in
    if jobs == "" then
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
                os: [${lib.concatStringsSep ", " ubuntuRunners}]
            runs-on: ''${{ matrix.os }}
            steps:
              - run: echo "No languages enabled; skipping per-version devenv test."
      ''
    else
      ''
        name: Test
        # TODO: cross-language version matrices (Rust × Python, …) are not supported.
        # Each language is tested independently for its supported versions.
        on:
          workflow_call:
        jobs:
        ${jobs}
      '';
}
