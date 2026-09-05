{
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
    "dyno"
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
      "languages.javascript or languages.typescript requires supported.javascript.runtimes (nodejs, bun, dyno)"
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
            description = "JS runtimes when javascript or typescript is on: nodejs, bun, dyno (Deno).";
          };
          nodejs = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
          };
          bun = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
          };
          dyno = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
            description = "Deno runtime version policy (languages.deno).";
          };
        };
      };
      default = { };
    };
  };

  config.packages = lib.throwIf (problems != [ ]) (lib.concatStringsSep "\n" problems) [ ];
}
