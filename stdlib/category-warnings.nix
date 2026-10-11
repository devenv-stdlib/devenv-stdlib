# Unused-category warnings for language and service category trees.
#
# When a category's toolchain is available (languages.<id>.enable /
# services.<id>.enable or categoryPolicies override) but nothing uses it —
# no enabled tool under that category prefix and no applied preset under the
# matching attrpath — emit a user-facing warning string.
#
# Checked paths:
# - lang.<id>          ↔ presets <id>.*
# - lang.<id>.linters  ↔ presets <id>.lint.*
# - services.<id>      ↔ presets services.<id>.*
#
# Any-of language groups (categoryPolicy.anyOfLanguageGroups, today
# javascript+typescript) share usage: an applied javascript.lint.prettier
# (javascript-or-typescript) counts for lang.typescript.linters too — e.g. the
# docs site enables TypeScript only and is formatted by shared Prettier.
#
# Opt out with stdlib.categoryWarnings.enable = false.
# Optional tool inventory: stdlib.categoryWarnings.toolIndex
#   ([ { name, category, enable } ]) so enabled tools count as usage.
{ lib }:
let
  supported = import ./devenv-supported.nix;
  categoryPolicy = import ./category-policy.nix { inherit lib; };
  report = import ./report.nix { inherit lib; };

  pathHasPrefix =
    prefix: path:
    let
      plen = builtins.length prefix;
    in
    builtins.length path >= plen && lib.take plen path == prefix;

  categoryHasPrefix = prefix: category: category == prefix || lib.hasPrefix "${prefix}." category;

  enabledToolsUnder =
    tools: prefix:
    lib.filter (t: (t.enable or false) && categoryHasPrefix prefix (t.category or "")) tools;

  appliedPresetsUnder =
    leaves: prefix:
    lib.filter (leaf: (leaf.result.applied or false) && pathHasPrefix prefix leaf.path) leaves;

  # Sibling languages from any-of policies (javascript ↔ typescript).
  siblingsOf =
    lang:
    lib.concatLists (
      map (
        group: if lib.elem lang group then lib.filter (l: l != lang) group else [ ]
      ) categoryPolicy.anyOfLanguageGroups
    );

  mkWarning = path: ''
    category ${path}: available but unused (no enabled tool or applied preset under this category)
  '';

  checks =
    let
      langChecks = lib.concatMap (
        lang:
        let
          siblings = siblingsOf lang;
        in
        [
          {
            path = "lang.${lang}";
            available = categoryPolicy.languageAvailable lang;
            toolPrefixes = [ "lang.${lang}" ] ++ map (s: "lang.${s}") siblings;
            presetPrefixes = [ [ lang ] ] ++ map (s: [ s ]) siblings;
          }
          {
            path = "lang.${lang}.linters";
            available = categoryPolicy.languageAvailable lang;
            toolPrefixes = [ "lang.${lang}.linters" ] ++ map (s: "lang.${s}.linters") siblings;
            presetPrefixes = [
              [
                lang
                "lint"
              ]
            ]
            ++ map (s: [
              s
              "lint"
            ]) siblings;
          }
        ]
      ) supported.languages;
      serviceChecks = map (svc: {
        path = "services.${svc}";
        available = categoryPolicy.serviceAvailable svc;
        toolPrefixes = [ "services.${svc}" ];
        presetPrefixes = [
          [
            "services"
            svc
          ]
        ];
      }) supported.services;
    in
    langChecks ++ serviceChecks;

  categoryUsed =
    tools: leaves: c:
    lib.any (prefix: enabledToolsUnder tools prefix != [ ]) c.toolPrefixes
    || lib.any (prefix: appliedPresetsUnder leaves prefix != [ ]) c.presetPrefixes;

  unusedPaths =
    {
      config,
      tools ? [ ],
      presets ? { },
      leaves ? null,
    }:
    let
      presetLeaves = if leaves != null then leaves else report.flattenPresetLeaves presets;
      active = lib.filter (c: c.available config) checks;
      unused = lib.filter (c: !(categoryUsed tools presetLeaves c)) active;
    in
    map (c: c.path) unused;

  unusedWarnings = args: map mkWarning (unusedPaths args);

  optionsModule =
    { lib, ... }:
    {
      options.stdlib.categoryWarnings = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            When true, warn about language/service categories that are
            available (languages.* / services.* / categoryPolicies) but have
            no enabled tool and no applied preset underneath. Shared any-of
            groups (javascript-or-typescript) count sibling lint/tool usage.
          '';
        };
        toolIndex = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption { type = lib.types.str; };
                category = lib.mkOption { type = lib.types.str; };
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                };
              };
            }
          );
          default = [ ];
          description = ''
            Optional tool inventory used when deciding if a category is in use.
            Each entry is { name, category, enable }. Den/HM loaders may fill
            this from discovered mkTool specs; devenv leaves it empty by default.
          '';
        };
      };
    };

  module =
    {
      config,
      lib,
      ...
    }:
    let
      args = {
        inherit config;
        tools = config.stdlib.categoryWarnings.toolIndex;
        presets = config.presets or { };
      };
    in
    {
      config = lib.mkIf config.stdlib.categoryWarnings.enable {
        warnings = unusedWarnings args;
      };
    };
in
{
  inherit
    checks
    unusedPaths
    unusedWarnings
    optionsModule
    module
    mkWarning
    pathHasPrefix
    categoryHasPrefix
    siblingsOf
    categoryUsed
    ;
}
