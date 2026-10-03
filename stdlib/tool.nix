# mkTool — public tool constructor.
#
# One API for every tool. Internally a tool is global (Home Manager / user
# profile), local (project / devenv), or both — inferred from which payloads
# are present. Enable options stay at tools.<leaf>.enable; inclusion uses
# nested attrpath refs (tools.python.lint.pyright), same idea as presets.
#
# A tool file is a module. Call it with `__stdlibMeta = true` to read the
# declaration without evaluating the module body.
#
# Categories and the loader live on stdlib/default.nix; this file is the
# tool schema.
{ lib }:
let
  categories = import ./categories.nix { inherit lib; };
  categoryPolicy = import ./category-policy.nix { inherit lib; };

  installKinds = [
    "nix"
    "catalog"
    "hm-program"
    "vscode-extension"
    "docker-image"
    # Local-only wiring (git-hooks / project config) with no discrete package pin.
    "project"
  ];

  upgradeKinds = [
    "flake"
    "catalog"
    "self"
    # No pin to bump; project-scoped hook/config only.
    "none"
  ];

  require = cond: message: if cond then true else throw message;

  hasPayload =
    spec: attr:
    let
      value = spec.${attr} or null;
    in
    value != null && value != { };

  # Global = HM profile; local = devenv/project. Same constructor either way.
  # When payloads are only attached in apply()/applyLocal (common for migrated
  # HM leaves), infer from install.kind so __stdlibMeta still works.
  scopesOf =
    spec:
    let
      global = hasPayload spec "homeManager";
      local = hasPayload spec "project";
      kind = (spec.install or { }).kind or null;
    in
    if global || local then
      lib.optional global "global" ++ lib.optional local "local"
    else if kind == "project" then
      [ "local" ]
    else
      [ "global" ];

  # Attrpath segments for a tool. Accept a list, or a single undotted leaf.
  normalizePath =
    value:
    if builtins.isList value then
      assert lib.assertMsg (
        value != [ ] && lib.all builtins.isString value
      ) "mkTool path: expected a non-empty list of attrpath segments";
      value
    else if builtins.isString value then
      assert lib.assertMsg (
        value != "" && !(lib.hasInfix "." value)
      ) "mkTool path: use a segment list (e.g. [ \"python\" \"lint\" \"pyright\" ]), not a dotted string";
      [ value ]
    else
      throw "mkTool path: expected attrpath segments (list of strings) or one leaf name";

  pathString = path: lib.concatStringsSep "." path;

  # Public inclusion path from category + leaf name:
  # lang.python.linters + pyright → python.lint.pyright
  # shell + bash → shell.bash
  # shell.history + atuin → shell.history.atuin
  pathFromCategory =
    category: name:
    let
      segs = lib.splitString "." category;
      withoutLang = if segs != [ ] && builtins.head segs == "lang" then builtins.tail segs else segs;
      mapped = map (s: if s == "linters" then "lint" else s) withoutLang;
    in
    mapped ++ [ name ];

  mkRef = path: {
    _type = "tool-ref";
    path = normalizePath path;
  };

  # Nested attrset of refs so callers write `with tools; [ python.lint.pyright ]`.
  refsFromPaths =
    paths:
    lib.foldl' (
      tree: path: lib.recursiveUpdate tree (lib.setAttrByPath (normalizePath path) (mkRef path))
    ) { } paths;

  refsFromSpecs =
    discovered:
    let
      paths = map (d: d.spec.path) discovered;
      ids = map pathString paths;
      dupes = lib.unique (lib.filter (id: lib.count (x: x == id) ids > 1) ids);
    in
    if dupes != [ ] then
      throw "mkTool: duplicate tool attrpaths: ${builtins.toString dupes}"
    else
      refsFromPaths paths;

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
      scopes = scopesOf spec;
      path = if spec ? path then normalizePath spec.path else pathFromCategory category name;
    in
    assert require (builtins.elem kind installKinds)
      "mkTool ${name}: install.kind ${kind} is not one of ${builtins.toString installKinds}";
    assert require (builtins.elem upgrade upgradeKinds)
      "mkTool ${name}: upgrade ${upgrade} is not one of ${builtins.toString upgradeKinds}";
    assert require (node ? cardinality) "mkTool ${name}: unknown category ${category}";
    assert require (
      scopes != [ ]
    ) "mkTool ${name}: set homeManager (global) and/or project (local) payload";
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
    assert require (
      kind != "project" || builtins.elem "local" scopes
    ) "mkTool ${name}: install.kind = project requires a project (local) payload";
    assert require (
      lib.last path == name
    ) "mkTool ${name}: path ${pathString path} must end with the tool leaf name";
    spec
    // {
      inherit
        name
        category
        scopes
        path
        ;
      categoryNode = node;
      dependsOn = spec.dependsOn or [ ];
      isGlobal = builtins.elem "global" scopes;
      isLocal = builtins.elem "local" scopes;
    };

  enableOption =
    checked:
    lib.mkOption {
      type = lib.types.bool;
      default = checked.defaultEnable or false;
      description = "Enable the ${checked.name} tool (${checked.category}; ${lib.concatStringsSep "+" checked.scopes}).";
    };

  # Argument for categoryPolicy.toolAssertions from a tool spec/meta.
  # Explicit `categoryPolicy` (including false = unbound) always wins —
  # Nix `or` only falls through on null/missing, so false is preserved.
  # Otherwise only dotted tool categories (lang.* / services.*) bind — bare
  # organizational categories like "shell" must not collide with language
  # policy ids after the devenv language scaffold.
  policyArgOf =
    checked:
    checked.categoryPolicy or (
      if builtins.isString checked.category && lib.hasInfix "." checked.category then
        checked.category
      else
        null
    );

  # Home Manager / Den leaf (global scope).
  apply =
    moduleArgs: spec:
    let
      checked = meta spec;
      cfgEnable = moduleArgs.config.tools.${checked.name}.enable;
      rendered = (spec.homeManager or (_: { })) moduleArgs;
      deps = checked.dependsOn;
      policyAssertions = categoryPolicy.toolAssertions moduleArgs.config (policyArgOf checked);
    in
    assert require checked.isGlobal
      "mkTool ${checked.name}: apply is for global (homeManager) tools; use applyLocal for project payloads";
    {
      imports = spec.imports or [ ];
      options = {
        tools.${checked.name}.enable = enableOption checked;
      }
      // (spec.options or { });
      config = lib.mkIf cfgEnable (
        lib.mkMerge [
          (lib.optionalAttrs (deps != [ ]) {
            tools = lib.genAttrs deps (_: {
              enable = true;
            });
          })
          {
            assertions =
              (map (dep: {
                assertion = moduleArgs.config.tools.${dep}.enable;
                message = "tools.${checked.name}.enable requires tools.${dep}.enable";
              }) deps)
              ++ policyAssertions;
          }
          rendered
        ]
      );
    };

  # devenv / project leaf (local scope). Never imports Den.
  applyLocal =
    moduleArgs: spec:
    let
      checked = meta spec;
      cfgEnable = moduleArgs.config.tools.${checked.name}.enable;
      raw = spec.project or { };
      rendered = if builtins.isFunction raw then raw moduleArgs else raw;
      deps = checked.dependsOn;
      policyAssertions = categoryPolicy.toolAssertions moduleArgs.config (policyArgOf checked);
    in
    assert require checked.isLocal "mkTool ${checked.name}: applyLocal is for local (project) tools";
    {
      imports = spec.imports or [ ];
      options = {
        tools.${checked.name}.enable = enableOption checked;
      }
      // (spec.options or { });
      config = lib.mkIf cfgEnable (
        lib.mkMerge [
          (lib.optionalAttrs (deps != [ ]) {
            tools = lib.genAttrs deps (_: {
              enable = true;
            });
          })
          {
            assertions =
              (map (dep: {
                assertion = moduleArgs.config.tools.${dep}.enable;
                message = "tools.${checked.name}.enable requires tools.${dep}.enable";
              }) deps)
              ++ policyAssertions;
          }
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
      }
      // lib.optionalAttrs (spec ? project) { inherit (spec) project; }
      // lib.optionalAttrs (!(spec ? project && !(spec ? homeManager))) {
        # Default global install unless the caller only passed project.
        homeManager =
          spec.homeManager or (
            { pkgs, ... }:
            {
              home.packages = [ pkgs.${spec.attr} ];
            }
          );
      };
    in
    if args.__stdlibMeta or false then
      meta base
    else if (meta base).isGlobal then
      apply args base
    else
      applyLocal args base;

  # Read tool declarations without evaluating Home Manager / devenv bodies.
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
    applyLocal
    nixLeaf
    specs
    scopesOf
    installKinds
    upgradeKinds
    policyArgOf
    normalizePath
    pathString
    pathFromCategory
    mkRef
    refsFromPaths
    refsFromSpecs
    ;
}
