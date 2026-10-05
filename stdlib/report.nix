# End-of-eval / enterShell inventory helpers. Pure formatting + sink builders.
# Leveled debug during realize uses stdlib.log; the forced summary goes through
# module warnings and devenv enterShell (no wrapper scripts).
# Preset identities are nested attrpaths (python.lint.ruff), not flat strings.
{
  lib,
  log ? null,
}:
let
  sort = lib.sort (a: b: a < b);
  pathString = path: lib.concatStringsSep "." path;

  asAttrs = value: if builtins.isAttrs value then value else { };

  # Walk nested presets.* (skip `strict` and non-leaf nodes).
  flattenPresetLeaves =
    presets:
    let
      walk =
        path: value:
        if !(builtins.isAttrs value) then
          [ ]
        else if value ? enable || value ? result then
          [
            {
              inherit path;
              id = pathString path;
              enable = value.enable or true;
              result =
                value.result or {
                  applied = false;
                  triggered = false;
                  inert = true;
                };
            }
          ]
        else
          lib.concatLists (
            lib.mapAttrsToList (name: child: walk (path ++ [ name ]) child) (
              builtins.removeAttrs value [ "strict" ]
            )
          );
    in
    walk [ ] (builtins.removeAttrs (asAttrs presets) [ "strict" ]);

  enabledHookNames =
    hooks:
    let
      hooks' = asAttrs hooks;
    in
    sort (lib.filter (name: (hooks'.${name} or { }).enable or false) (builtins.attrNames hooks'));

  # treefmt-nix programs.<name>.enable → sorted enabled formatter/linter ids.
  # Skip obsolete aliases: reading programs.ruff.enable traces
  # "Obsolete option … renamed to programs.ruff-check.enable" via
  # treefmt-nix's mkRenamedOptionModule (numtide/treefmt-nix programs/ruff-check.nix).
  treefmtObsoleteProgramAliases = [ "ruff" ];

  enabledTreefmtPrograms =
    programs:
    let
      programs' = asAttrs programs;
      names = lib.subtractLists treefmtObsoleteProgramAliases (builtins.attrNames programs');
    in
    sort (lib.filter (name: (programs'.${name} or { }).enable or false) names);

  presetInventory =
    presets:
    let
      leaves = flattenPresetLeaves presets;
      applied = sort (map (leaf: leaf.id) (lib.filter (leaf: leaf.result.applied or false) leaves));
      inert = sort (
        map (leaf: leaf.id) (
          lib.filter (leaf: (leaf.result.triggered or false) && !(leaf.result.applied or false)) leaves
        )
      );
      disabled = sort (map (leaf: leaf.id) (lib.filter (leaf: !(leaf.enable or true)) leaves));
    in
    {
      inherit
        applied
        inert
        disabled
        ;
    };

  # Walk nested tools.* trees. A leaf is any attrs with a bool `enable`
  # (tools.<leaf>.enable today; tools.<category>….<leaf>.enable if nested).
  flattenToolLeaves =
    tools:
    let
      walk =
        path: value:
        if !(builtins.isAttrs value) then
          [ ]
        else if builtins.isBool (value.enable or null) then
          [
            {
              inherit path;
              inherit (value) enable;
              id = pathString path;
            }
          ]
        else
          lib.concatLists (lib.mapAttrsToList (name: child: walk (path ++ [ name ]) child) value);
    in
    walk [ ] (asAttrs tools);

  toolInventory =
    tools:
    let
      leaves = flattenToolLeaves tools;
      enabled = sort (map (leaf: leaf.id) (lib.filter (leaf: leaf.enable) leaves));
    in
    {
      inherit enabled;
    };

  matrixInventory =
    {
      empty ? false,
      runners ? [ ],
      languages ? { },
    }:
    {
      inherit empty runners;
      languages = lib.mapAttrs (
        _:
        {
          enabled ? false,
          rows ? [ ],
        }:
        {
          inherit enabled;
          cells = map (
            row:
            lib.concatStringsSep "/" (
              lib.filter (s: s != null && s != "") [
                (row.os or null)
                (row.implementation or null)
                (row.python_version or null)
                (row.channel or null)
                (row.version or null)
                (row.runtime or null)
              ]
            )
          ) rows;
        }
      ) languages;
    };

  inventory =
    {
      presets ? { },
      tools ? { },
      gitHooks ? { },
      # treefmt.config.programs attrset (first-class linters via devenv treefmt).
      treefmtPrograms ? { },
      matrix ? null,
      # Dotted category paths available but unused (stdlib.categoryWarnings).
      unusedCategories ? [ ],
    }:
    {
      presets = presetInventory presets;
      tools = toolInventory tools;
      gitHooks = {
        enabled = enabledHookNames gitHooks;
      };
      treefmt = {
        enabled = enabledTreefmtPrograms treefmtPrograms;
      };
      matrix = if matrix == null then null else matrixInventory matrix;
      unusedCategories = sort unusedCategories;
    };

  formatSection =
    title: lines:
    if lines == [ ] then [ "${title}: (none)" ] else [ "${title}:" ] ++ map (line: "  - ${line}") lines;

  formatMatrix =
    matrix:
    if matrix == null then
      [ "Build matrix: (not available in this evaluator)" ]
    else if matrix.empty or false then
      [
        "Build matrix: empty (no-language-matrix)"
        "  runners: ${lib.concatStringsSep ", " (matrix.runners or [ ])}"
      ]
    else
      let
        langs = matrix.languages or { };
        langLines = lib.concatLists (
          map (
            name:
            let
              entry = langs.${name};
            in
            if !(entry.enabled or false) then
              [ ]
            else
              [
                "${name}: ${
                  if entry.cells == [ ] then "(enabled, no version rows)" else lib.concatStringsSep ", " entry.cells
                }"
              ]
          ) (sort (builtins.attrNames langs))
        );
      in
      [ "Build matrix (test.yml strategy):" ]
      ++ map (line: "  - ${line}") langLines
      ++ [ "  runners: ${lib.concatStringsSep ", " (matrix.runners or [ ])}" ];

  # Shown after Enabled tools so enterShell / warnings point at per-leaf cheats.
  toolsNaviHint = "Use navi <tool name> to understand its usage.";

  formatReport =
    inv:
    lib.concatStringsSep "\n" (
      [ "stdlib status:" ]
      ++ formatSection "Applied presets" (inv.presets.applied or [ ])
      ++ formatSection "Inert presets (triggered, not applied)" (inv.presets.inert or [ ])
      ++ formatSection "Enabled tools" (inv.tools.enabled or [ ])
      ++ [ toolsNaviHint ]
      ++ formatSection "Enabled linters (treefmt)" (inv.treefmt.enabled or [ ])
      ++ formatSection "Enabled git-hooks / pre-commit" (inv.gitHooks.enabled or [ ])
      ++ formatSection "Unused available categories" (inv.unusedCategories or [ ])
      ++ formatMatrix (inv.matrix or null)
    );

  mkEvalWarning = formatReport;

  mkEnterShellSnippet =
    inv:
    let
      text = formatReport inv;
      escaped = lib.replaceStrings [ "'" ] [ "'\\''" ] text;
    in
    ''
      printf '%s\n' '${escaped}'
    '';

  logInventory =
    inv:
    if log == null then
      inv
    else
      log.debug' "stdlib.report inventory" {
        applied = builtins.length (inv.presets.applied or [ ]);
        hooks = builtins.length (inv.gitHooks.enabled or [ ]);
        unusedCategories = builtins.length (inv.unusedCategories or [ ]);
        matrixEmpty = (inv.matrix or { }).empty or null;
      } inv;
in
{
  inherit
    inventory
    formatReport
    mkEvalWarning
    mkEnterShellSnippet
    enabledHookNames
    enabledTreefmtPrograms
    matrixInventory
    flattenPresetLeaves
    flattenToolLeaves
    logInventory
    toolsNaviHint
    ;
}
