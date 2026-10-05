# Category-wide policies for namespaced language and service categories.
#
# Declared once per category (not copied onto every leaf). When any preset
# under `<lang>.*` or tool under `lang.<lang>.*` is used/enabled, the category
# policy's prerequisites must hold. Service categories use `services.<id>.*`
# presets / `services.<id>` tools the same way against `services.<id>.enable`.
#
# Each language id (python, rust, …) must be available via
# `languages.<id>.enable` or an explicit override
# `stdlib.categoryPolicies.<id>.available = true`.
#
# Service policy ids are `services.<id>` (matching the category annotation).
#
# Language/service ids come from stdlib/devenv-supported.nix. Set
# `categoryPolicy` on the matching node in categories.nix (generated there).
{ lib }:
let
  supported = import ./devenv-supported.nix;

  # Flexible "toolchain available somehow" for a devenv language id.
  languageAvailable =
    lang: cfg:
    ((cfg.languages.${lang} or { }).enable or false)
    || ((cfg.stdlib.categoryPolicies.${lang} or { }).available or false);

  serviceAvailable =
    svc: cfg:
    let
      policyId = "services.${svc}";
    in
    ((cfg.services.${svc} or { }).enable or false)
    || ((cfg.stdlib.categoryPolicies.${policyId} or { }).available or false);

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

  mkServicePolicy = svc: {
    id = "services.${svc}";
    presetRoot = "services";
    toolCategoryPrefix = "services.${svc}";
    available = serviceAvailable svc;
    message = ''
      category services.${svc}: ${svc} must be available (set services.${svc}.enable or stdlib.categoryPolicies."services.${svc}".available = true)
    '';
  };

  # Shared JS/TS presets live under javascript.* but apply when either
  # language is available. Leaves set categoryPolicy = "javascript-or-typescript".
  # Groups feed unused-category warnings so sibling lint usage counts for both.
  anyOfLanguageGroups = [
    [
      "javascript"
      "typescript"
    ]
  ];

  mkAnyLanguagePolicy =
    langs:
    let
      id = lib.concatStringsSep "-or-" langs;
      listed = lib.concatStringsSep " / " (
        map (lang: "languages.${lang}.enable or stdlib.categoryPolicies.${lang}.available") langs
      );
    in
    {
      inherit id;
      presetRoot = builtins.head langs;
      toolCategoryPrefix = "lang.${builtins.head langs}";
      available = cfg: lib.any (lang: languageAvailable lang cfg) langs;
      message = ''
        category ${builtins.head langs}: one of ${lib.concatStringsSep ", " langs} must be available (set ${listed} = true)
      '';
    };

  languagePolicies = lib.listToAttrs (
    map (lang: {
      name = lang;
      value = mkLanguagePolicy lang;
    }) supported.languages
  );

  servicePolicies = lib.listToAttrs (
    map (svc: {
      name = "services.${svc}";
      value = mkServicePolicy svc;
    }) supported.services
  );

  policies =
    languagePolicies
    // servicePolicies
    // {
      javascript-or-typescript = mkAnyLanguagePolicy (builtins.head anyOfLanguageGroups);
    };

  policyIds = lib.sort (a: b: a < b) (builtins.attrNames policies);

  forId = id: policies.${id} or null;

  forPresetPath =
    path:
    if path == [ ] then
      null
    else if builtins.head path == "services" && builtins.length path >= 2 then
      forId "services.${builtins.elemAt path 1}"
    else
      forId (builtins.head path);

  forToolCategory =
    dotted:
    let
      parts = lib.splitString "." dotted;
    in
    if builtins.length parts >= 2 && builtins.head parts == "lang" then
      forId (builtins.elemAt parts 1)
    else if builtins.length parts >= 2 && builtins.head parts == "services" then
      forId "services.${builtins.elemAt parts 1}"
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
  # `policy` null → derive from path head; false → unbound; string → policies.<id>.
  bindPreset =
    {
      path,
      when ? null,
      requires ? [ ],
      policy ? null,
    }:
    let
      resolved =
        if policy == false then
          null
        else if builtins.isString policy then
          forId policy
        else
          forPresetPath path;
    in
    {
      policy = resolved;
      when = if when != null then when else inheritedWhen resolved;
      requires = requires ++ requiresOf resolved;
    };

  # Module assertions for an enabled tool under a category policy.
  # `categoryOrPolicy` may be a tool category path (lang.javascript.linters)
  # or an explicit policy id (javascript-or-typescript / shell) from the tool
  # spec's `categoryPolicy`. Pass null/false for unbound tools.
  # Callers (mkTool) must not pass bare organizational categories like "shell"
  # here — those collide with language policy ids after the devenv scaffold;
  # use tool.policyArgOf so only explicit categoryPolicy or dotted lang.*/services.*
  # categories bind.
  toolAssertions =
    config: categoryOrPolicy:
    let
      # Dotted strings are tool categories (lang.python.linters). Bare names are
      # explicit policy ids (javascript-or-typescript). null/false → unbound.
      policy =
        if categoryOrPolicy == null || categoryOrPolicy == false then
          null
        else if builtins.isString categoryOrPolicy && lib.hasInfix "." categoryOrPolicy then
          forToolCategory categoryOrPolicy
        else if builtins.isString categoryOrPolicy && policies ? ${categoryOrPolicy} then
          forId categoryOrPolicy
        else
          null;
    in
    map (req: {
      assertion = if builtins.isFunction req.assertion then req.assertion config else req.assertion;
      inherit (req) message;
    }) (requiresOf policy);

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
                languages.<id>.enable (or services.<id>.enable for
                services.* policy ids). Use when the toolchain is provided
                outside devenv languages.* / services.*.
              '';
            };
          }
        );
        default = { };
        description = ''
          Per-category policy overrides. Enabling any preset under <id>.* or
          tool under lang.<id>.* (or services.<id>.*) requires the category
          to be available (languages.<id>.enable / services.<id>.enable or
          categoryPolicies.<id>.available).
        '';
      };
    };
in
{
  inherit
    policies
    policyIds
    anyOfLanguageGroups
    languageAvailable
    serviceAvailable
    mkLanguagePolicy
    mkServicePolicy
    mkAnyLanguagePolicy
    forId
    forPresetPath
    forToolCategory
    forCategoryNode
    inheritedWhen
    requiresOf
    bindPreset
    toolAssertions
    optionsModule
    supported
    ;
}
