# mkPreset — when vs requires, strict flag, hub aspect + den.policies.
# Category excludes stay on the selected tool's node (not cousins).
# Preset identity is a nested attrpath (python.lint.ruff), not a flat string.
# Composability: one preset per tool by default; bundle only when tools must
# ship together (e.g. terminal.alacritty-atuin). Multi-tool language stacks
# belong in consumer compositions (see presets/examples/).
{
  lib,
  categories ? import ./categories.nix { inherit lib; },
  toolLib ? import ./tool.nix { inherit lib; },
  categoryPolicy ? import ./category-policy.nix { inherit lib; },
}:
let
  # stdlib/categories.nix is `{ tree, resolve, ... }`. A raw node tree
  # (the nested-exclude test) is handled by categoryExcludes directly.
  categoriesTree = categories.tree or categories;

  load = import ./load.nix { inherit lib; };

  # Attrpath segments for a building-block preset. Accept a list, or a single
  # undotted leaf name (tests / one-segment hubs like `ide`).
  normalizePath =
    value:
    if builtins.isList value then
      assert lib.assertMsg (
        value != [ ] && lib.all builtins.isString value
      ) "mkPreset path: expected a non-empty list of attrpath segments";
      value
    else if builtins.isString value then
      assert lib.assertMsg (
        value != "" && !(lib.hasInfix "." value)
      ) "mkPreset path: use a segment list (e.g. [ \"python\" \"lint\" \"ruff\" ]), not a dotted string";
      [ value ]
    else
      throw "mkPreset path: expected attrpath segments (list of strings) or one leaf name";

  pathString = path: lib.concatStringsSep "." path;

  mkRef = path: {
    _type = "preset-ref";
    path = normalizePath path;
  };

  # Nested attrset of refs so callers write `with presets; [ python.lint.ruff ]`.
  refsFromPaths =
    paths:
    lib.foldl' (
      tree: path: lib.recursiveUpdate tree (lib.setAttrByPath (normalizePath path) (mkRef path))
    ) { } paths;

  # includes take preset refs (attrpaths), never bare string literals.
  normalizeInclude =
    item:
    if builtins.isAttrs item && item._type or null == "preset-ref" then
      pathString item.path
    else if builtins.isAttrs item && item ? path then
      pathString (normalizePath item.path)
    else if builtins.isList item then
      pathString (normalizePath item)
    else if builtins.isString item then
      throw "mkPreset includes: use attrpath refs (e.g. with presets; [ python.lint.ruff ]), not string literals"
    else
      throw "mkPreset includes: expected a preset attrpath ref";

  normalizeIncludes = items: map normalizeInclude items;

  getPresetAttr =
    cfg: path: attr:
    lib.attrByPath (path ++ [ attr ]) null (cfg.presets or { });

  isExclusive = cardinality: cardinality == "exactly-one" || cardinality == "zero-or-one";

  indexTree =
    tree:
    let
      walk =
        path: node:
        let
          here = {
            inherit path;
            cardinality = node.cardinality or "any-of";
            tools = node.tools or [ ];
          };
          children = node.children or { };
          below = lib.concatLists (lib.mapAttrsToList (name: child: walk (path ++ [ name ]) child) children);
        in
        [ here ] ++ below;
    in
    lib.concatLists (lib.mapAttrsToList (name: node: walk [ name ] node) tree);

  # Tool names selected under an exactly-one / zero-or-one node exclude the
  # other tools registered on that same node. Cousins on other branches, and
  # tools on ancestor or child nodes, are left alone.
  categoryExcludes =
    tree: selectedNames:
    let
      atNode =
        node:
        let
          chosen = lib.filter (name: builtins.elem name selectedNames) node.tools;
        in
        if isExclusive node.cardinality && chosen != [ ] then
          lib.filter (name: !(builtins.elem name chosen)) node.tools
        else
          [ ];
    in
    lib.unique (lib.concatLists (map atNode (indexTree tree)));

  # Tool names live on mkTool specs. A few nodes also list `tools` in
  # categories.nix. Siblings are names that share one category path.
  registry =
    let
      fromTree = lib.concatMap (
        node:
        map (name: {
          inherit name;
          category = lib.concatStringsSep "." node.path;
        }) node.tools
      ) (indexTree categoriesTree);
      fromSpecs = map (found: {
        inherit (found.spec) name category;
      }) (toolLib.specs (load.discover [ ../tools ]));
    in
    fromTree ++ fromSpecs;

  grouped = lib.groupBy (entry: entry.category) registry;

  resolveCategory = dotted: if categories ? resolve then categories.resolve dotted else null;

  siblingExcludes =
    selectedNames:
    lib.unique (
      lib.concatLists (
        map (
          name:
          let
            hit = lib.findFirst (entry: entry.name == name) null registry;
            category = if hit == null then null else hit.category;
            node = if category == null then null else resolveCategory category;
            names = lib.unique (map (entry: entry.name) (grouped.${category} or [ ]));
          in
          if node == null || !(isExclusive node.cardinality) then
            [ ]
          else
            lib.filter (other: other != name) names
        ) selectedNames
      )
    );

  registryFailures =
    presetName: selectedNames:
    lib.concatLists (
      lib.mapAttrsToList (
        category: entries:
        let
          names = lib.unique (map (entry: entry.name) entries);
          chosen = lib.filter (name: builtins.elem name selectedNames) names;
          node = resolveCategory category;
        in
        lib.optional (node != null && isExclusive node.cardinality && builtins.length chosen > 1) {
          assertion = false;
          message = "preset ${presetName}: category ${category} is ${node.cardinality} but selects ${lib.concatStringsSep ", " chosen}";
        }
      ) grouped
    );

  # tools= takes tool attrpath refs (same nesting as categories / presets),
  # never bare string literals like "pyright".
  normalizeTool =
    item:
    if builtins.isAttrs item && item._type or null == "tool-ref" then
      let
        path = toolLib.normalizePath item.path;
        name = lib.last path;
      in
      {
        inherit name path;
        aspect = name;
      }
    else if builtins.isAttrs item && item ? path && !(item ? name && item ? category) then
      let
        path = toolLib.normalizePath item.path;
        name = lib.last path;
      in
      {
        inherit name path;
        aspect = item.aspect or name;
      }
    else if builtins.isList item then
      let
        path = toolLib.normalizePath item;
        name = lib.last path;
      in
      {
        inherit name path;
        aspect = name;
      }
    else if builtins.isAttrs item && item ? name then
      let
        built =
          if item ? category && builtins.isAttrs (item.install or null) && item ? upgrade then
            toolLib.meta item
          else
            item;
        path =
          if built ? path then
            toolLib.normalizePath built.path
          else if built ? category then
            toolLib.pathFromCategory built.category built.name
          else
            [ built.name ];
      in
      {
        inherit (built) name;
        inherit path;
        aspect = item.aspect or built.name;
      }
    else if builtins.isString item then
      throw "mkPreset tools: use attrpath refs (e.g. tools = [ tools.python.lint.pyright ]), not string literals"
    else
      throw "mkPreset tools: expected a tool attrpath ref or mkTool attrset";

  normalizeTools =
    cfg: raw:
    let
      items = if builtins.isFunction raw then raw cfg else raw;
    in
    map normalizeTool items;

  predicate = cfg: value: if builtins.isFunction value then value cfg else value;

  hostClass =
    ctx:
    let
      host = ctx.host or { };
      explicit = host.class or null;
      system = toString (host.system or "");
    in
    if explicit != null then
      explicit
    else if lib.hasSuffix "-darwin" system then
      "darwin"
    else if system != "" then
      "nixos"
    else
      ctx.class or null;

  checkRequires =
    cfg: reqs:
    map (
      req:
      let
        raw = req.assertion or false;
      in
      {
        assertion = if builtins.isFunction raw then raw cfg else raw;
        message = req.message or "preset requirement failed";
      }
    ) reqs;

  realize =
    {
      name,
      cfg ? { },
      enable ? true,
      strict ? true,
      globalStrict ? true,
      when ? (_: true),
      requires ? [ ],
      tools ? [ ],
      exclude ? [ ],
      aspectAlias ? { },
    }:
    let
      triggered = enable && predicate cfg when;
      normalized = if triggered then normalizeTools cfg tools else [ ];
      selectedNames = map (tool: tool.name) normalized;
      checked =
        if triggered then checkRequires cfg (requires ++ registryFailures name selectedNames) else [ ];
      failed = lib.filter (req: !req.assertion) checked;
      useStrict = strict && globalStrict;
      strictFail = triggered && failed != [ ] && useStrict;
      applied = triggered && failed == [ ];
      inert = !applied;
      warnings =
        if triggered && !useStrict && failed != [ ] then
          map (req: "preset ${name} is inert: ${req.message}") failed
        else
          [ ];
      alias = toolName: aspectAlias.${toolName} or toolName;
      excludeTools = if applied then siblingExcludes selectedNames else [ ];
      excludeAspects =
        ctx:
        let
          extra =
            if !applied then
              [ ]
            else if builtins.isFunction exclude then
              exclude ctx
            else
              exclude;
        in
        lib.unique ((map alias excludeTools) ++ extra);
      decision = {
        inherit
          name
          triggered
          applied
          inert
          warnings
          ;
        assertions = if triggered && useStrict then checked else [ ];
        includeTools = if applied then selectedNames else [ ];
        includeAspects = if applied then map (tool: alias tool.name) normalized else [ ];
        inherit excludeTools excludeAspects;
      };
    in
    if strictFail then
      throw ''
        preset ${name} requirements failed:
        ${lib.concatMapStringsSep "\n" (req: "- ${req.message}") failed}
      ''
    else
      decision;

  mergePayload =
    config: result: configure: payload:
    let
      configured = if builtins.isFunction configure then configure config else configure;
      extra = {
        inherit (result) assertions warnings;
      };
    in
    if builtins.isFunction payload then
      args:
      lib.mkMerge [
        (payload args)
        configured
        extra
      ]
    else
      lib.mkMerge [
        payload
        configured
        extra
      ];

  # Skip aspect names that are not in this Den fixpoint.
  aspectRefs =
    den: names:
    lib.filter (aspect: aspect != null) (map (aspectName: den.aspects.${aspectName} or null) names);
in
{
  inherit
    realize
    categoryExcludes
    hostClass
    categoriesTree
    normalizePath
    pathString
    mkRef
    refsFromPaths
    normalizeInclude
    normalizeIncludes
    normalizeTool
    normalizeTools
    getPresetAttr
    ;

  mkPreset =
    {
      # Nested attrpath identity: [ "python" "lint" "ruff" ] → presets.python.lint.ruff
      # and Den aspect/policy key "python.lint.ruff". `name` is a one-segment alias.
      path ? null,
      name ? null,
      description ? "",
      # null = inherit category-policy when (or always-true when no policy).
      when ? null,
      requires ? [ ],
      # null = derive from path; string = policies.<id>; false = unbound.
      # Named policyId so it does not shadow the categoryPolicy import.
      policyId ? null,
      tools ? [ ],
      configure ? { },
      homeManager ? { },
      project ? { },
      includes ? [ ],
      exclude ? [ ],
      aspectAlias ? { },
      extraOptions ? { },
    }:
    let
      presetPath =
        if path != null then
          normalizePath path
        else if name != null then
          normalizePath name
        else
          throw "mkPreset: path (attrpath segments) is required";
      presetId = pathString presetPath;
      includeIds = normalizeIncludes includes;
      bound = categoryPolicy.bindPreset {
        path = presetPath;
        inherit when requires;
        policy = policyId;
      };
    in
    {
      den,
      config,
      lib,
      ...
    }:
    let
      globalStrict = config.presets.strict or true;
      enable = getPresetAttr config presetPath "enable";
      enable' = if enable == null then true else enable;
      strict = getPresetAttr config presetPath "strict";
      strict' = if strict == null then true else strict;
      result = realize {
        name = presetId;
        inherit (bound) when;
        inherit (bound) requires;
        inherit
          tools
          exclude
          aspectAlias
          ;
        enable = enable';
        strict = strict';
        inherit globalStrict;
        cfg = config;
      };
      aspectBody = {
        includes = [
          den.policies.${presetId}
        ]
        ++ aspectRefs den result.includeAspects
        ++ aspectRefs den includeIds;
        homeManager = mergePayload config result configure homeManager;
      }
      // lib.optionalAttrs (builtins.isFunction project || project != { }) {
        project = mergePayload config result configure project;
      };
      presetOptions = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = if description == "" then "Enable the ${presetId} preset." else description;
        };
        strict = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Throw when this preset's requirements fail. false warns and leaves it inert.";
        };
        result = lib.mkOption {
          type = lib.types.raw;
          internal = true;
          description = "Lowered preset decision for tests and evaluators.";
        };
      }
      // extraOptions;
    in
    {
      options = lib.recursiveUpdate {
        presets.strict = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "When false, failed preset requirements warn and the preset stays inert.";
        };
      } (lib.setAttrByPath ([ "presets" ] ++ presetPath) presetOptions);

      config = lib.recursiveUpdate {
        den.aspects.${presetId} = lib.mkIf result.applied aspectBody;
        den.policies.${presetId} = lib.mkIf result.applied (
          ctx:
          let
            inherit (den.lib) policy;
          in
          map (aspect: policy.include aspect) (aspectRefs den result.includeAspects)
          ++ map (aspect: policy.exclude aspect) (aspectRefs den (result.excludeAspects ctx))
        );
      } (lib.setAttrByPath ([ "presets" ] ++ presetPath ++ [ "result" ]) result);
    };
}
