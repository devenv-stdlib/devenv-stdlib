# Category-wide policies for namespaced language categories.
#
# Declared once per category (not copied onto every leaf). When any preset
# under `<lang>.*` or tool under `lang.<lang>.*` is used/enabled, the category
# policy's prerequisites must hold.
#
# Each language id (python, rust, …) must be available via
# `languages.<id>.enable` or an explicit override
# `stdlib.categoryPolicies.<id>.available = true`.
#
# Add an entry to `policies` and set `categoryPolicy` on the matching
# `lang.<id>` node in categories.nix.
{ lib }:
let
  # Flexible "toolchain available somehow" for a devenv language id.
  languageAvailable =
    lang: cfg:
    ((cfg.languages.${lang} or { }).enable or false)
    || ((cfg.stdlib.categoryPolicies.${lang} or { }).available or false);

  mkLanguagePolicy = lang: {
    id = lang;
    # Preset attrpath root: python.lint.ruff → python
    presetRoot = lang;
    # Tool category prefix: lang.python / lang.python.linters
    toolCategoryPrefix = "lang.${lang}";
    available = languageAvailable lang;
    message = ''
      category ${lang}: ${lang} must be available (set languages.${lang}.enable or stdlib.categoryPolicies.${lang}.available = true)
    '';
  };

  # Language categories with presets (python, rust, …). Add an entry and set
  # categoryPolicy on lang.<id> in categories.nix.
  policies = {
    go = mkLanguagePolicy "go";
    python = mkLanguagePolicy "python";
    rust = mkLanguagePolicy "rust";
  };

  policyIds = lib.sort (a: b: a < b) (builtins.attrNames policies);

  forId = id: policies.${id} or null;

  forPresetPath = path: if path == [ ] then null else forId (builtins.head path);

  forToolCategory =
    dotted:
    let
      parts = lib.splitString "." dotted;
    in
    if builtins.length parts >= 2 && builtins.head parts == "lang" then
      forId (builtins.elemAt parts 1)
    else
      null;

  # Walk a categories.nix node for an annotated categoryPolicy id.
  forCategoryNode =
    categories: dotted:
    let
      fromConvention = forToolCategory dotted;
      node = categories.resolve dotted;
      annotated = node.categoryPolicy or null;
    in
    if annotated != null then forId annotated else fromConvention;

  inheritedWhen = policy: if policy == null then (_: true) else policy.available;

  requiresOf =
    policy:
    if policy == null then
      [ ]
    else
      [
        {
          assertion = policy.available;
          inherit (policy) message;
        }
      ];

  # Effective when/requires for a preset declaration under a category policy.
  # Omitting `when` inherits the category available predicate. Category requires
  # are always appended so an explicit `when = _: true` still fails closed.
  bindPreset =
    {
      path,
      when ? null,
      requires ? [ ],
    }:
    let
      policy = forPresetPath path;
    in
    {
      inherit policy;
      when = if when != null then when else inheritedWhen policy;
      requires = requires ++ requiresOf policy;
    };

  # Module assertions for an enabled tool under a category policy.
  toolAssertions =
    config: category:
    map (req: {
      assertion = if builtins.isFunction req.assertion then req.assertion config else req.assertion;
      inherit (req) message;
    }) (requiresOf (forToolCategory category));

  # devenv / HM option: explicit availability override per category id.
  optionsModule =
    { lib, ... }:
    {
      options.stdlib.categoryPolicies = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.available = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Treat this category's toolchain as available without
                languages.<id>.enable. Use when Python (etc.) is provided
                outside devenv languages.*.
              '';
            };
          }
        );
        default = { };
        description = ''
          Per-category policy overrides. Enabling any preset under <id>.* or
          tool under lang.<id>.* requires the category to be available
          (languages.<id>.enable or categoryPolicies.<id>.available).
        '';
      };
    };
in
{
  inherit
    policies
    policyIds
    languageAvailable
    mkLanguagePolicy
    forId
    forPresetPath
    forToolCategory
    forCategoryNode
    inheritedWhen
    requiresOf
    bindPreset
    toolAssertions
    optionsModule
    ;
}
