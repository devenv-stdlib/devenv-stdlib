{
  pkgs,
  lib,
  config,
  ...
}:
let
  langOn = name: (config.languages.${name} or { }).enable or false;
  pythonOn = langOn "python";
  rustOn = langOn "rust";
  goOn = langOn "go";
  javascriptOn = langOn "javascript" || langOn "typescript";

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

  versionPolicy =
    extra:
    {
      min = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Minimum supported version (required when the language is enabled).";
      };
      max = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional maximum supported version.";
      };
      unsupported = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Versions between min and max that must not be used (for example a Rust ICE).";
      };
      versions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Versions to test in CI. Defaults to min and max (if set), minus unsupported.";
      };
    }
    // extra;

  resolvedVersions =
    policy:
    let
      raw =
        if policy.min == null then
          [ ]
        else if policy.versions != [ ] then
          policy.versions
        else
          [ policy.min ] ++ lib.optional (policy.max != null && policy.max != policy.min) policy.max;
    in
    lib.filter (v: !(lib.elem v policy.unsupported)) raw;

  inRange =
    policy: v:
    lib.versionAtLeast v policy.min
    && (policy.max == null || lib.versionAtLeast policy.max v)
    && !(lib.elem v policy.unsupported);

  py = config.supported.python;
  rs = config.supported.rust;
  go = config.supported.go;
  js = config.supported.javascript;

  problems = lib.flatten [
    (lib.optional (pythonOn && py.min == null) "languages.python.enable requires supported.python.min")
    (lib.optional (
      pythonOn && py.min != null && lib.versionOlder py.min "3"
    ) "supported.python.min must be Python 3 or above (got ${py.min})")
    (lib.optional (
      pythonOn && py.max != null && lib.versionOlder py.max "3"
    ) "supported.python.max must be Python 3 or above (got ${py.max})")
    (lib.optional (
      pythonOn && py.max != null && py.min != null && lib.versionOlder py.max py.min
    ) "supported.python.max (${py.max}) is older than min (${py.min})")
    (lib.optional (
      pythonOn && py.implementations == [ ]
    ) "supported.python.implementations must include cpython and/or pypy")
    (lib.optional (
      pythonOn && py.min != null && !(lib.all (inRange py) (resolvedVersions py))
    ) "supported.python.versions must sit between min and max and omit unsupported")

    (lib.optional (rustOn && rs.min == null) "languages.rust.enable requires supported.rust.min")
    (lib.optional (
      rustOn && rs.max != null && rs.min != null && lib.versionOlder rs.max rs.min
    ) "supported.rust.max (${rs.max}) is older than min (${rs.min})")
    (lib.optional (
      rustOn && !(lib.elem "stable" rs.channels)
    ) "supported.rust.channels must include stable")
    (lib.optional (
      rustOn && rs.min != null && !(lib.all (inRange rs) (resolvedVersions rs))
    ) "supported.rust.versions must sit between min and max and omit unsupported")

    (lib.optional (goOn && go.min == null) "languages.go.enable requires supported.go.min")
    (lib.optional (
      goOn && go.max != null && go.min != null && lib.versionOlder go.max go.min
    ) "supported.go.max (${go.max}) is older than min (${go.min})")
    (lib.optional (
      goOn && go.min != null && !(lib.all (inRange go) (resolvedVersions go))
    ) "supported.go.versions must sit between min and max and omit unsupported")

    (lib.optional (javascriptOn && js.runtimes == [ ])
      "languages.javascript or languages.typescript requires supported.javascript.runtimes (nodejs, bun, deno)"
    )
    (lib.concatMap (
      runtime:
      let
        pol = js.${runtime};
        label = "supported.javascript.${runtime}";
      in
      lib.optionals (javascriptOn && lib.elem runtime js.runtimes) [
        (lib.optional (pol.min == null) "${label}.min is required when ${runtime} is selected")
        (lib.optional (
          pol.max != null && pol.min != null && lib.versionOlder pol.max pol.min
        ) "${label}.max (${pol.max}) is older than min (${pol.min})")
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
      runs-on: ubuntu-latest
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

  pythonRows = lib.concatMap (
    impl:
    map (version: {
      implementation = impl;
      inherit version;
      python_version = if impl == "pypy" then "pypy${version}" else version;
    }) (resolvedVersions py)
  ) py.implementations;

  rustRows =
    map (version: {
      channel = "stable";
      inherit version;
    }) (resolvedVersions rs)
    ++ map (channel: {
      inherit channel;
      version = "latest";
    }) (lib.filter (c: c != "stable") rs.channels);

  goRows = map (version: { inherit version; }) (resolvedVersions go);

  javascriptRows = lib.concatMap (
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

  rawJobs = lib.concatStrings (
    lib.optional pythonOn (
      jobYaml "python" pythonRows
        "devenv --option languages.python.enable:bool true --option languages.python.version:string \${{ matrix.python_version }} test"
    )
    ++ lib.optional rustOn (
      jobYaml "rust" rustRows
        "devenv --option languages.rust.enable:bool true --option languages.rust.channel:string \${{ matrix.channel }} --option languages.rust.version:string \${{ matrix.version }} test"
    )
    ++ lib.optional goOn (
      jobYaml "go" goRows
        "devenv --option languages.go.enable:bool true --option languages.go.version:string \${{ matrix.version }} test"
    )
    ++ lib.optional javascriptOn (
      jobYaml "javascript" javascriptRows ''
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

  languageJobs = if rawJobs == "" then "" else padJob rawJobs;

  workflowText =
    if languageJobs == "" then
      ''
        name: Test
        # TODO: cross-language version matrices (Rust × Python, …) are not supported.
        on:
          push:
            branches: [main, master]
          pull_request:
        jobs:
          no-language-matrix:
            runs-on: ubuntu-latest
            steps:
              - run: echo No languages enabled; skipping per-version devenv test.
      ''
    else
      ''
        name: Test
        # TODO: cross-language version matrices (Rust × Python, …) are not supported.
        # Each language is tested independently for its supported versions.
        on:
          push:
            branches: [main, master]
          pull_request:
        jobs:
        ${languageJobs}
      '';

  workflowFile = lib.throwIf (problems != [ ]) (lib.concatStringsSep "\n" problems) (
    pkgs.writeText "test.yml" workflowText
  );
in
{
  options.supported = {
    python = lib.mkOption {
      type = lib.types.submodule {
        options = versionPolicy {
          implementations = lib.mkOption {
            type = lib.types.listOf (lib.types.enum pythonImpls);
            default = [ "cpython" ];
            description = "Python 3 implementations to test. cpython and/or pypy.";
          };
        };
      };
      default = { };
    };
    rust = lib.mkOption {
      type = lib.types.submodule {
        options = versionPolicy {
          channels = lib.mkOption {
            type = lib.types.listOf (lib.types.enum rustChannels);
            default = [ "stable" ];
            description = "Rust channels. stable is required; beta and nightly are optional extras.";
          };
        };
      };
      default = { };
    };
    go = lib.mkOption {
      type = lib.types.submodule { options = versionPolicy { }; };
      default = { };
    };
    javascript = lib.mkOption {
      type = lib.types.submodule {
        options = {
          runtimes = lib.mkOption {
            type = lib.types.listOf (lib.types.enum jsRuntimes);
            default = [ ];
            description = "JS runtimes when javascript or typescript is on: nodejs, bun, deno.";
          };
          nodejs = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
          };
          bun = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
          };
          deno = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
            description = "Deno runtime version policy (languages.deno).";
          };
        };
      };
      default = { };
    };
  };

  config = {
    scripts.sync-language-versions-workflow.exec = ''
      set -euo pipefail
      dest="$DEVENV_ROOT/.github/workflows/test.yml"
      mkdir -p "$(dirname "$dest")"
      tmp="$(mktemp)"
      cp ${lib.escapeShellArg workflowFile} "$tmp"
      if ! cmp -s "$tmp" "$dest" 2>/dev/null; then
        mv "$tmp" "$dest"
        echo "wrote .github/workflows/test.yml"
      else
        rm -f "$tmp"
      fi
    '';

    enterShell = ''
      sync-language-versions-workflow
    '';
  };
}
