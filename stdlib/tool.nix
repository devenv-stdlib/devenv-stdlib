# mkTool — public tool constructor (P1).
#
# A tool file is a Home Manager module. Call it with `__stdlibMeta = true`
# to read the declaration without evaluating the module body.
#
# P0 owns categories and the loader. This file is the tool schema.
{ lib }:
let
  categories = import ./categories.nix { inherit lib; };

  installKinds = [
    "nix"
    "catalog"
    "hm-program"
    "vscode-extension"
    "docker-image"
  ];

  upgradeKinds = [
    "flake"
    "catalog"
    "self"
  ];

  require = cond: message: if cond then true else throw message;

  meta =
    spec:
    let
      name = spec.name or (throw "mkTool: name is required");
      category = spec.category or (throw "mkTool ${name}: category is required");
      install = spec.install or (throw "mkTool ${name}: install is required");
      kind = install.kind or (throw "mkTool ${name}: install.kind is required");
      upgrade = spec.upgrade or (throw "mkTool ${name}: upgrade is required");
      # categories.resolve throws on an unknown path.
      node = categories.resolve category;
    in
    assert require (builtins.elem kind installKinds)
      "mkTool ${name}: install.kind ${kind} is not one of ${builtins.toString installKinds}";
    assert require (builtins.elem upgrade upgradeKinds)
      "mkTool ${name}: upgrade ${upgrade} is not one of ${builtins.toString upgradeKinds}";
    assert require (node ? cardinality) "mkTool ${name}: unknown category ${category}";
    assert require (
      kind != "nix" || (install ? attr && builtins.isString install.attr && install.attr != "")
    ) "mkTool ${name}: install.kind = nix requires install.attr (a nixpkgs attribute name)";
    assert require (
      kind != "hm-program"
      || (install ? program && builtins.isString install.program && install.program != "")
    ) "mkTool ${name}: install.kind = hm-program requires install.program";
    assert require (
      kind != "catalog" || (install ? name && builtins.isString install.name && install.name != "")
    ) "mkTool ${name}: install.kind = catalog requires install.name";
    spec
    // {
      inherit name category;
      categoryNode = node;
      dependsOn = spec.dependsOn or [ ];
    };

  apply =
    moduleArgs: spec:
    let
      checked = meta spec;
      cfgEnable = moduleArgs.config.tools.${checked.name}.enable;
      rendered = (spec.homeManager or (_: { })) moduleArgs;
      deps = checked.dependsOn;
    in
    {
      imports = spec.imports or [ ];
      options = {
        tools.${checked.name}.enable = lib.mkOption {
          type = lib.types.bool;
          default = spec.defaultEnable or false;
          description = "Enable the ${checked.name} tool (${checked.category}).";
        };
      }
      // (spec.options or { });
      config = lib.mkIf cfgEnable (
        lib.mkMerge [
          (lib.optionalAttrs (deps != [ ]) {
            tools = lib.genAttrs deps (_: {
              enable = true;
            });
            assertions = map (dep: {
              assertion = moduleArgs.config.tools.${dep}.enable;
              message = "tools.${checked.name}.enable requires tools.${dep}.enable";
            }) deps;
          })
          rendered
        ]
      );
    };

  # Nix package leaf: install.kind = nix, package is pkgs.<attr>.
  nixLeaf =
    args: spec:
    let
      base = {
        inherit (spec) name category;
        install = {
          kind = "nix";
          inherit (spec) attr;
        };
        upgrade = spec.upgrade or "flake";
        defaultEnable = spec.defaultEnable or false;
        dependsOn = spec.dependsOn or [ ];
      };
    in
    if args.__stdlibMeta or false then
      meta base
    else
      apply args (
        base
        // {
          homeManager =
            { pkgs, ... }:
            {
              home.packages = [ pkgs.${spec.attr} ];
            };
        }
      );

  # Read tool declarations without evaluating Home Manager bodies.
  specs =
    files:
    let
      discovered = map (file: {
        inherit file;
        spec = import file {
          inherit lib;
          # Required so the module is an HM function (needs pkgs), not a Den
          # submodule fn. The meta probe never reads these.
          pkgs = { };
          config = { };
          __stdlibMeta = true;
        };
      }) files;
      names = map (d: d.spec.name) discovered;
      dupes = lib.unique (lib.filter (n: lib.count (x: x == n) names > 1) names);
    in
    if dupes != [ ] then
      throw "mkTool: duplicate tool name(s): ${builtins.toString dupes}"
    else
      discovered;
in
{
  inherit
    meta
    apply
    nixLeaf
    specs
    installKinds
    upgradeKinds
    ;
}
