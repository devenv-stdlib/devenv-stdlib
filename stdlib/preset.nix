# mkPreset — when vs requires, strict flag, hub aspect + den.policies.
# Category excludes stay on the selected tool's node (not cousins).
{
  lib,
  categories ? import ./categories.nix { inherit lib; },
  toolLib ? import ./tool.nix { inherit lib; },
}:
let
  # P1 stdlib/categories.nix is `{ tree, resolve, ... }`. A raw node tree
  # (the nested-exclude test) is handled by categoryExcludes directly.
  categoriesTree = categories.tree or categories;

  load = import ./load.nix { inherit lib; };

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

  # Tool names live on mkTool specs (P1). A few nodes also list `tools` in
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
        name = found.spec.name;
        category = found.spec.category;
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

  normalizeTool =
    item:
    if builtins.isString item then
      {
        name = item;
        aspect = item;
      }
    else if builtins.isAttrs item && item ? name then
      let
        built =
          if item ? category && builtins.isAttrs (item.install or null) && item ? upgrade then
            toolLib.meta item
          else
            item;
      in
      {
        inherit (built) name;
        aspect = item.aspect or built.name;
      }
    else
      throw "mkPreset tools: expected a tool name or mkTool attrset";

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
    ;

  mkPreset =
    {
      name,
      description ? "",
      when ? (_: true),
      requires ? [ ],
      tools ? [ ],
      configure ? { },
      homeManager ? { },
      project ? { },
      includes ? [ ],
      exclude ? [ ],
      aspectAlias ? { },
      extraOptions ? { },
    }:
    {
      den,
      config,
      lib,
      ...
    }:
    let
      globalStrict = config.presets.strict or true;
      enable = config.presets.${name}.enable or true;
      strict = config.presets.${name}.strict or true;
      result = realize {
        inherit
          name
          when
          requires
          tools
          exclude
          aspectAlias
          enable
          strict
          globalStrict
          ;
        cfg = config;
      };
      aspectBody = {
        includes = [
          den.policies.${name}
        ]
        ++ aspectRefs den result.includeAspects
        ++ aspectRefs den includes;
        homeManager = mergePayload config result configure homeManager;
      }
      // lib.optionalAttrs (builtins.isFunction project || project != { }) {
        project = mergePayload config result configure project;
      };
    in
    {
      options.presets.strict = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "When false, failed preset requirements warn and the preset stays inert.";
      };

      options.presets.${name} = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = if description == "" then "Enable the ${name} preset." else description;
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

      config = {
        presets.${name}.result = result;
        den.aspects.${name} = lib.mkIf result.applied aspectBody;
        den.policies.${name} = lib.mkIf result.applied (
          ctx:
          let
            policy = den.lib.policy;
          in
          map (aspect: policy.include aspect) (aspectRefs den result.includeAspects)
          ++ map (aspect: policy.exclude aspect) (aspectRefs den (result.excludeAspects ctx))
        );
      };
    };
}
