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

  categoryHasPrefix =
    prefix: category:
    category == prefix || lib.hasPrefix "${prefix}." category;

  enabledToolsUnder =
    tools: prefix:
    lib.filter (t: (t.enable or false) && categoryHasPrefix prefix (t.category or "")) tools;

  appliedPresetsUnder =
    leaves: prefix:
    lib.filter (leaf: (leaf.result.applied or false) && pathHasPrefix prefix leaf.path) leaves;

  mkWarning = path: ''
    category ${path}: available but unused (no enabled tool or applied preset under this category)
  '';

  checks =
    let
      langChecks = lib.concatMap (
        lang:
        [
          {
            path = "lang.${lang}";
            available = categoryPolicy.languageAvailable lang;
            toolPrefix = "lang.${lang}";
            presetPrefix = [ lang ];
          }
          {
            path = "lang.${lang}.linters";
            available = categoryPolicy.languageAvailable lang;
            toolPrefix = "lang.${lang}.linters";
            presetPrefix = [
              lang
              "lint"
            ];
          }
        ]
      ) supported.languages;
      serviceChecks = map (svc: {
        path = "services.${svc}";
        available = categoryPolicy.serviceAvailable svc;
        toolPrefix = "services.${svc}";
        presetPrefix = [
          "services"
          svc
        ];
      }) supported.services;
    in
    langChecks ++ serviceChecks;

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
      unused = lib.filter (
        c:
        enabledToolsUnder tools c.toolPrefix == [ ]
        && appliedPresetsUnder presetLeaves c.presetPrefix == [ ]
      ) active;
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
            no enabled tool and no applied preset underneath.
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
    ;
}
