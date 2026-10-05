# Tool-declared devenv tasks and preset composition helpers.
#
# Tools declare named task leaves on the mkTool spec (`tasks`). Leaf names are
# qualified as "<tool>:<leaf>" (e.g. mr-boxington:gc). Presets export those
# tasks into the devenv task graph and/or compose before/after edges around an
# anchor task to form development workflows.
#
# See docs (Context): tool-devenv-tasks.md
{ lib }:
let
  taskId = toolName: leaf: "${toolName}:${leaf}";

  mkTaskRef = toolName: leaf: {
    _type = "task-ref";
    id = taskId toolName leaf;
    tool = toolName;
    inherit leaf;
  };

  # Nested refs so callers write `tasks.mr-boxington.gc` after refsFromSpecs.
  refsFromSpecs =
    discovered:
    lib.foldl' (
      tree: d:
      let
        inherit (d.spec) name;
        leaves = builtins.attrNames (d.spec.tasks or { });
      in
      if leaves == [ ] then
        tree
      else
        lib.recursiveUpdate tree (
          lib.setAttrByPath [ name ] (
            lib.listToAttrs (map (leaf: lib.nameValuePair leaf (mkTaskRef name leaf)) leaves)
          )
        )
    ) { } discovered;

  normalizeTaskId =
    item:
    if builtins.isString item then
      item
    else if builtins.isAttrs item && item._type or null == "task-ref" then
      item.id
    else if builtins.isAttrs item && item ? id then
      item.id
    else
      throw "stdlib.tasks: expected a task id string or task-ref";

  # Resolve a tasks declaration (attrset or moduleArgs → attrset).
  resolve =
    moduleArgs: decl:
    if decl == null || decl == { } then
      { }
    else if builtins.isFunction decl then
      decl moduleArgs
    else if builtins.isAttrs decl then
      decl
    else
      throw "stdlib.tasks: expected an attrset or moduleArgs → attrset";

  # Keep only selected leaf names (unqualified). null = all.
  select =
    only: tasks:
    if only == null then tasks else lib.filterAttrs (leaf: _: builtins.elem leaf only) tasks;

  # Qualify leaf names under the tool namespace. Already-qualified keys pass through.
  qualify =
    toolName: tasks:
    lib.mapAttrs' (
      leaf: body:
      let
        id = if lib.hasInfix ":" leaf then leaf else taskId toolName leaf;
      in
      lib.nameValuePair id body
    ) tasks;

  # Build config.tasks attrs for one tool's declaration.
  lower =
    {
      name,
      tasks ? { },
      only ? null,
      moduleArgs ? { },
    }:
    qualify name (select only (resolve moduleArgs tasks));

  # Normalize exportTasks items:
  #   - tool-ref → export all leaves (from ref.tasks if present, else discovered)
  #   - { tool = <ref|name>; only = [ "gc" ]; } → subset
  #   - string tool name (legacy tests) → export all
  normalizeExport =
    item:
    if builtins.isAttrs item && item._type or null == "tool-ref" then
      {
        name = item.name or (lib.last item.path);
        only = null;
        tasks = item.tasks or null;
      }
    else if builtins.isAttrs item && item ? tool then
      let
        inherit (item) tool;
        name =
          if builtins.isAttrs tool && tool._type or null == "tool-ref" then
            tool.name or (lib.last tool.path)
          else if builtins.isAttrs tool && tool ? name then
            tool.name
          else if builtins.isString tool then
            tool
          else
            throw "stdlib.tasks.export: tool must be a tool-ref, mkTool meta, or name";
        tasks =
          if builtins.isAttrs tool && tool._type or null == "tool-ref" then
            tool.tasks or null
          else
            null;
      in
      {
        inherit name tasks;
        only = item.only or null;
      }
    else if builtins.isAttrs item && item ? name then
      {
        inherit (item) name;
        only = item.only or null;
        tasks = item.tasks or null;
      }
    else if builtins.isString item then
      {
        name = item;
        only = null;
        tasks = null;
      }
    else
      throw "stdlib.tasks.export: expected a tool-ref or { tool, only? }";

  # Look up a discovered tool spec by leaf name.
  specByName =
    discovered: name:
    let
      hit = lib.findFirst (d: d.spec.name == name) null discovered;
    in
    if hit == null then null else hit.spec;

  # Lower exportTasks against discovered tool specs, or against tasks embedded
  # on tool-refs from refsFromSpecs (so load may omit tool roots).
  export =
    {
      items ? [ ],
      discovered ? [ ],
      moduleArgs ? { },
    }:
    let
      parts = map (
        raw:
        let
          item = normalizeExport raw;
          spec = specByName discovered item.name;
          tasks =
            if item.tasks != null then
              item.tasks
            else if spec != null then
              spec.tasks or { }
            else
              throw "stdlib.tasks.export: unknown tool ${item.name}";
        in
        lower {
          inherit (item) name only;
          inherit moduleArgs tasks;
        }
      ) items;
    in
    lib.foldl' lib.recursiveUpdate { } parts;

  # Compose before/after edges around an anchor task.
  # Satellite tasks declare the edge (doctor.before = [ build ], gc.after = [ build ]).
  compose =
    {
      around,
      before ? [ ],
      after ? [ ],
    }:
    let
      around' = normalizeTaskId around;
      before' = map normalizeTaskId before;
      after' = map normalizeTaskId after;
    in
    lib.foldl' lib.recursiveUpdate { } (
      map (b: {
        ${b}.before = [ around' ];
      }) before'
      ++ map (a: {
        ${a}.after = [ around' ];
      }) after'
    );

  # Lower a list of workflow attrs (same shape as compose).
  workflows = items: lib.foldl' lib.recursiveUpdate { } (map compose items);

  # True when the host module system declares `options.tasks` (devenv).
  hostHasTasks = moduleArgs: (moduleArgs.options or { }) ? tasks;
in
{
  inherit
    taskId
    mkTaskRef
    refsFromSpecs
    normalizeTaskId
    resolve
    select
    qualify
    lower
    normalizeExport
    specByName
    export
    compose
    workflows
    hostHasTasks
    ;
}
