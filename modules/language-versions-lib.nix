{ lib }:
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

  runner = "ubuntu-22.04";

  inherit emptyPolicy;

  emptyPython = emptyPolicy // {
    implementations = [ "cpython" ];
  };

  emptyRust = emptyPolicy // {
    channels = [ "stable" ];
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

  inRange =
    policy: v:
    lib.versionAtLeast v policy.min
    && (policy.max == null || lib.versionAtLeast policy.max v)
    && !(lib.elem v policy.unsupported);

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
        pythonOn && !rangeStepOk python
      ) "supported.python.min and max must differ in exactly one component (or set versions explicitly)")
      (lib.optional (
        pythonOn && python.implementations == [ ]
      ) "supported.python.implementations must include cpython and/or pypy")
      (lib.optional (
        pythonOn && python.min != null && !(lib.all (inRange python) (resolvedVersions python))
      ) "supported.python.versions must sit between min and max and omit unsupported")

      (lib.optional (rustOn && rust.min == null) "languages.rust.enable requires supported.rust.min")
      (lib.optional (
        rustOn && rust.max != null && rust.min != null && lib.versionOlder rust.max rust.min
      ) "supported.rust.max (${rust.max}) is older than min (${rust.min})")
      (lib.optional (
        rustOn && !rangeStepOk rust
      ) "supported.rust.min and max must differ in exactly one component (or set versions explicitly)")
      (lib.optional (
        rustOn && !(lib.elem "stable" rust.channels)
      ) "supported.rust.channels must include stable")
      (lib.optional (
        rustOn && rust.min != null && !(lib.all (inRange rust) (resolvedVersions rust))
      ) "supported.rust.versions must sit between min and max and omit unsupported")

      (lib.optional (goOn && go.min == null) "languages.go.enable requires supported.go.min")
      (lib.optional (
        goOn && go.max != null && go.min != null && lib.versionOlder go.max go.min
      ) "supported.go.max (${go.max}) is older than min (${go.min})")
      (lib.optional (
        goOn && !rangeStepOk go
      ) "supported.go.min and max must differ in exactly one component (or set versions explicitly)")
      (lib.optional (
        goOn && go.min != null && !(lib.all (inRange go) (resolvedVersions go))
      ) "supported.go.versions must sit between min and max and omit unsupported")

      (lib.optional (javascriptOn && javascript.runtimes == [ ])
        "languages.javascript or languages.typescript requires supported.javascript.runtimes (nodejs, bun, deno)"
      )
      (lib.concatMap (
        runtime:
        let
          pol = javascript.${runtime};
          label = "supported.javascript.${runtime}";
        in
        lib.optionals (javascriptOn && lib.elem runtime javascript.runtimes) [
          (lib.optional (pol.min == null) "${label}.min is required when ${runtime} is selected")
          (lib.optional (
            pol.max != null && pol.min != null && lib.versionOlder pol.max pol.min
          ) "${label}.max (${pol.max}) is older than min (${pol.min})")
          (lib.optional (
            !rangeStepOk pol
          ) "${label}.min and max must differ in exactly one component (or set versions explicitly)")
          (lib.optional (
            pol.min != null && !(lib.all (inRange pol) (resolvedVersions pol))
          ) "${label}.versions must sit between min and max and omit unsupported")
        ]
      ) jsRuntimes)
    ];

  matrixRow =
    attrs:
    let
      names = lib.attrNames attrs;
      fmt = name: "${name}: \"${toString attrs.${name}}\"";
    in
    "        - ${fmt (lib.head names)}"
    + lib.concatMapStrings (name: "\n          ${fmt name}") (lib.tail names);

  jobYaml = name: rows: testRun: ''
    ${name}:
      runs-on: ${runner}
      strategy:
        fail-fast: false
        matrix:
          include:
    ${lib.concatMapStringsSep "\n" matrixRow rows}
      steps:
        - uses: actions/checkout@v4
        - uses: cachix/install-nix-action@v31
          with:
            extra_nix_config: |
              extra-substituters = https://devenv.cachix.org
              extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
        - uses: cachix/cachix-action@v16
          with:
            name: devenv
        - name: Install devenv
          run: nix profile install nixpkgs#devenv
        - name: Test
          run: ${testRun}
  '';

  nodePackage = version: "nodejs_${lib.versions.major version}";

  pythonRows =
    py:
    lib.concatMap (
      impl:
      map (version: {
        implementation = impl;
        inherit version;
        python_version = if impl == "pypy" then "pypy${version}" else version;
      }) (resolvedVersions py)
    ) py.implementations;

  rustRows =
    rs:
    map (version: {
      channel = "stable";
      inherit version;
    }) (resolvedVersions rs)
    ++ map (channel: {
      inherit channel;
      version = "latest";
    }) (lib.filter (c: c != "stable") rs.channels);

  goRows = go: map (version: { inherit version; }) (resolvedVersions go);

  javascriptRows =
    js:
    lib.concatMap (
      runtime:
      map (
        version:
        {
          inherit runtime version;
        }
        // lib.optionalAttrs (runtime == "nodejs") { pkg = nodePackage version; }
      ) (resolvedVersions js.${runtime})
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
            "devenv --option languages.python.enable:bool true --option languages.python.version:string \${{ matrix.python_version }} test"
        )
        ++ lib.optional rustOn (
          jobYaml "rust" (rustRows rust)
            "devenv --option languages.rust.enable:bool true --option languages.rust.channel:string \${{ matrix.channel }} --option languages.rust.version:string \${{ matrix.version }} test"
        )
        ++ lib.optional goOn (
          jobYaml "go" (goRows go)
            "devenv --option languages.go.enable:bool true --option languages.go.version:string \${{ matrix.version }} test"
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
            runs-on: ${runner}
            steps:
              - run: echo No languages enabled; skipping per-version devenv test.
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
