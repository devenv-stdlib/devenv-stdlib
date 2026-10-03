# Plain devenv loader. Do not import Den here: devenv evaluation must not
# fetch Den. Condition checks go through realize in stdlib/preset.nix.
# mkPreset's Den aspect module is not imported into this evaluator.
#
# Preset identity is a nested attrpath mirroring tool categories
# (python.lint.ruff), not a flat string name.
#
# Logging goes through stdlib.log (nix-log is private). End-of-eval report
# uses module warnings + enterShell — no wrapper scripts.
#
# Local mkTool leaves (project payload) live under tools/** and are lowered
# here via applyLocal. Thin presets list tool names; when applied they set
# tools.<name>.enable = true. Same public API as global tools.
#
# Call sites import this file directly; stdlib/default.nix and
# stdlib/load.nix remain the public stdlib entrypoints.
{
  lib,
  nix-log ? null,
}:
let
  presetLib = import ./preset.nix { inherit lib; };
  toolLib = import ./tool.nix { inherit lib; };
  loadLib = import ./load.nix { inherit lib; };
  categoryPolicy = import ./category-policy.nix { inherit lib; };
  projectLib = import ../modules/lib/project.nix { inherit lib; };
  log = import ./log.nix { inherit lib nix-log; };
  report = import ./report.nix { inherit lib log; };

  # Selected-pack order matches former modules/ides (rust, go, python, then the
  # shared JS/TS pack). javascript is visited before typescript so lib.unique
  # keeps a single typescript server / extension pack.
  surfaceOrder = [
    "rust"
    "go"
    "python"
    "javascript"
    "typescript"
  ];

  # Matches project.debtmapLanguages.
  debtmapOrder = [
    "rust"
    "python"
    "javascript"
    "typescript"
    "go"
  ];

  nixSettings = {
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = [
      "devenv"
      "lsp"
    ];
    "[nix]" = {
      "editor.defaultFormatter" = "jnoortheen.nix-ide";
      "editor.insertSpaces" = true;
      "editor.tabSize" = 2;
    };
  };

  # Collect .nix files with path segments relative to `root`, prefixed by the
  # root directory basename (presets/python/lint/ruff.nix → python.lint.ruff).
  collect =
    root: prefix:
    let
      entries = builtins.readDir root;
      names = lib.sort (a: b: a < b) (builtins.attrNames entries);
      files = lib.filter (
        name: entries.${name} == "regular" && lib.hasSuffix ".nix" name && !(lib.hasPrefix "_" name)
      ) names;
      dirs = lib.filter (name: entries.${name} == "directory" && !(lib.hasPrefix "_" name)) names;
    in
    map (name: {
      file = root + "/${name}";
      path = prefix ++ [ (lib.removeSuffix ".nix" name) ];
    }) files
    ++ lib.concatMap (name: collect (root + "/${name}") (prefix ++ [ name ])) dirs;

  isPreset =
    value:
    builtins.isAttrs value
    && ((value ? path && builtins.isList value.path) || (value ? name && builtins.isString value.name));

  loadEntry =
    entry:
    let
      decl = import entry.file { inherit lib; };
      presetPath =
        if decl ? path then
          presetLib.normalizePath decl.path
        else if decl ? name then
          # Directory layout is authoritative when name is a leftover leaf.
          entry.path
        else
          entry.path;
      presetId = presetLib.pathString presetPath;
    in
    if isPreset decl then
      decl
      // {
        path = presetPath;
        name = presetId;
      }
    else
      throw "stdlib.devenv.load: ${toString entry.file} must return a preset declaration";

  declsOf =
    roots:
    let
      entries = lib.concatMap (
        root:
        let
          base = baseNameOf (toString root);
        in
        collect root [ base ]
      ) roots;
      decls = map loadEntry entries;
      ids = map (decl: decl.name) decls;
      dupes = lib.filter (id: lib.count (x: x == id) ids > 1) (lib.unique ids);
    in
    if dupes != [ ] then
      throw "stdlib.devenv.load: duplicate preset attrpaths: ${toString dupes}"
    else
      decls;

  refsOf = roots: presetLib.refsFromPaths (map (decl: decl.path) (declsOf roots));

  debtmapLanguages = langs: lib.concatMap (name: (langs.${name} or { }).debtmap or [ ]) debtmapOrder;

  serenaLanguageServers =
    langs:
    projectLib.serenaAlwaysLanguageServers
    ++ lib.unique (lib.concatMap (name: (langs.${name} or { }).serena or [ ]) surfaceOrder);

  langType = lib.types.submodule {
    options = {
      serena = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Serena language_servers ids this preset adds.";
      };
      debtmap = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "debtmap languages.enabled ids this preset adds.";
      };
      vscodeIds = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Editor extension ids recommended when this preset is active.";
      };
      extensionSet = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "home/ides/ext-lib.nix pack name to symlink, or null.";
      };
      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "VS Code / Cursor settings merged into the sync script.";
      };
      ciMatrix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Include this language in the generated test.yml matrix.";
      };
    };
  };

  leafOptions =
    config: decl:
    let
      id = decl.name;
    in
    {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Apply the ${id} preset when its when condition holds.";
      };
      strict = lib.mkOption {
        type = lib.types.bool;
        default = config.presets.strict;
        description = "Unmet requires throw. Set false to warn and skip ${id}.";
      };
      result = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {
          applied = false;
          triggered = false;
          inert = true;
        };
        internal = true;
        description = "Realize decision for ${id} (stdlib.report).";
      };
    };

  presetOptions =
    decls:
    { config, ... }:
    {
      options = lib.foldl' lib.recursiveUpdate {
        presets.strict = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            When true, unmet preset requires fail evaluation.
            When false, devenv warns and leaves the preset inert.
            presets.<attrpath>.strict overrides this per preset.
          '';
        };

        stdlib = {
          lang = lib.mkOption {
            type = lib.types.attrsOf langType;
            default = { };
            description = ''
              Per-tool language-scoped preset contributions. stdlib.devenv.load
              lowers these into Serena, editor recommendations, debtmap, and CI
              matrix flags.
            '';
          };

          markers = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            internal = true;
            description = "Exemplar markers for fixture presets. Not a public API.";
          };

          report = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Emit the stdlib status summary via warnings / enterShell.";
            };
            enterShell = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Print the status summary on devenv enterShell.";
            };
          };
        };
      } (map (decl: lib.setAttrByPath ([ "presets" ] ++ decl.path) (leafOptions config decl)) decls);
    };

  hasProjectPayload =
    decl:
    let
      raw = decl.project or null;
    in
    raw != null && raw != { };

  applyPreset =
    decl:
    {
      config,
      lib,
      pkgs ? { },
      ...
    }:
    let
      enable = presetLib.getPresetAttr config decl.path "enable";
      strict = presetLib.getPresetAttr config decl.path "strict";
      # Category policy: omit `when` to inherit category availability; category
      # requires are always appended (fail closed if when is forced true).
      bound = categoryPolicy.bindPreset {
        inherit (decl) path;
        when = decl.when or null;
        requires = decl.requires or [ ];
        # Optional override: string policy id, or false to skip category binding.
        policy = decl.categoryPolicy or null;
      };
      # realize throws when strict requirements fail. Non-strict failures
      # come back as warnings and applied = false.
      decision = presetLib.realize {
        inherit (decl) name;
        inherit (bound) when;
        inherit (bound) requires;
        tools = decl.tools or [ ];
        cfg = config;
        enable = if enable == null then true else enable;
        strict = if strict == null then true else strict;
        globalStrict = config.presets.strict;
      };
      logged =
        if decision.applied then
          log.info' "preset applied" { inherit (decl) name; } decision
        else if decision.triggered then
          log.debug' "preset inert" { inherit (decl) name; } decision
        else
          log.debug' "preset not triggered" { inherit (decl) name; } decision;
      result = {
        inherit (logged)
          applied
          triggered
          inert
          warnings
          ;
        includeTools = logged.includeTools or [ ];
      };
      projectConfig =
        if !(hasProjectPayload decl) then
          { }
        else if lib.isFunction decl.project then
          decl.project {
            inherit
              config
              lib
              pkgs
              ;
          }
        else
          decl.project;
    in
    {
      imports = lib.optional (decl ? module && decl.module != null) decl.module;
      config = lib.mkMerge [
        {
          inherit (logged) assertions warnings;
        }
        (lib.setAttrByPath ([ "presets" ] ++ decl.path ++ [ "result" ]) result)
        # Project payload only. Tool enables are lowered in enablePresetTools
        # so tools.* merges do not re-enter realize via mkIf logged.applied.
        (lib.mkIf logged.applied projectConfig)
      ];
    };

  # After applyPreset writes presets.<path>.result, enable the local tools that
  # result.includeTools lists. Reading result.applied (not re-running realize)
  # keeps this out of the tools↔presets fixed-point cycle.
  enablePresetTools =
    decl:
    {
      config,
      options,
      lib,
      ...
    }:
    let
      presets = config.presets or { };
      applied = lib.attrByPath (
        decl.path
        ++ [
          "result"
          "applied"
        ]
      ) false presets;
      includeTools = lib.attrByPath (
        decl.path
        ++ [
          "result"
          "includeTools"
        ]
      ) [ ] presets;
      # Presets may list HM-only / aspect names; only wire declared local tools.
      names = lib.filter (name: options ? tools && options.tools ? ${name}) includeTools;
    in
    {
      config = lib.mkIf (applied && names != [ ]) {
        tools = lib.genAttrs names (_: {
          enable = lib.mkDefault true;
        });
      };
    };

  # Local mkTool modules (isLocal / project payload). File is the module.
  localToolModules =
    toolRoots:
    let
      discovered = toolLib.specs (loadLib.discover toolRoots);
      local = lib.filter (d: d.spec.isLocal) discovered;
    in
    map (d: d.file) local;

  normalizeLoadArgs =
    rootsOrAttrs:
    if builtins.isList rootsOrAttrs then
      {
        presets = rootsOrAttrs;
        tools = [ ];
      }
    else
      {
        presets = rootsOrAttrs.presets or [ ];
        tools = rootsOrAttrs.tools or [ ];
      };

  lower =
    {
      config,
      lib,
      pkgs ? { },
      ...
    }:
    let
      langs = config.stdlib.lang;
      extraNames = lib.filter (name: !(lib.elem name surfaceOrder)) (builtins.attrNames langs);
      order = surfaceOrder ++ lib.sort (a: b: a < b) extraNames;
      wantedIds = lib.unique (lib.concatMap (name: (langs.${name} or { }).vscodeIds or [ ]) order);
      allIds =
        projectLib.vscodeLanguageIds.rust
        ++ projectLib.vscodeLanguageIds.go
        ++ projectLib.vscodeLanguageIds.python
        ++ projectLib.vscodeLanguageIds.typescript;
      recommendations = projectLib.vscodeAlwaysRecommend ++ wantedIds;
      unwantedRecommendations = lib.subtractLists wantedIds allIds;
      settings = lib.foldl' (
        acc: name: acc // ((langs.${name} or { }).settings or { })
      ) nixSettings order;
      extensionSets = lib.unique (
        lib.filter (name: name != null) (map (name: (langs.${name} or { }).extensionSet or null) order)
      );
      idesLib = import ../modules/ides/lib.nix { inherit pkgs lib; };
      selected = lib.concatMap (name: idesLib.ext.${name}) extensionSets;
    in
    {
      config = {
        files.".serena/project.yml".yaml = {
          project_name = config.name or "devenv-shell";
          language_servers = serenaLanguageServers langs;
          encoding = "utf-8";
          activation_command = null;
          activation_command_timeout = 180.0;
          line_ending = null;
          language_backend = null;
          ignore_all_files_in_gitignore = true;
          ls_specific_settings = { };
          ls_workspace_folders = [ "." ];
          ls_additional_workspace_folders = [ ];
          ignored_paths = [ ];
          read_only = false;
          excluded_tools = [ ];
          included_optional_tools = [ ];
          fixed_tools = [ ];
          default_modes = null;
          added_modes = null;
          initial_prompt = "";
          symbol_info_budget = null;
          read_only_memory_patterns = [ ];
          ignored_memory_patterns = [ ];
        };

        files.".vscode/extensions.json".json = {
          inherit recommendations unwantedRecommendations;
        };

        # Internal: lets fixture tests see merged editor settings without
        # evaluating the extension symlink script (that needs nixpkgs).
        stdlib.markers.ideSettings = settings;

        # Package symlinks stay lazy so unit tests can read files without nixpkgs.
        scripts.cursor-sync-extensions.exec = idesLib.mkSyncScript {
          extensionsDir = "$HOME/.cursor/extensions";
          logPrefix = "cursor";
          inherit selected settings;
        };
        scripts.vscode-sync-extensions.exec = idesLib.mkSyncScript {
          extensionsDir = "$HOME/.vscode/extensions";
          logPrefix = "ides";
          inherit selected settings;
        };

        enterShell = ''
          cursor-sync-extensions
        '';
      };
    };

  # Forced summary after all presets realize. warnings = end of eval;
  # enterShell = Nix-built echo (not a wrapper script).
  reportModule =
    {
      config,
      lib,
      ...
    }:
    let
      inv = report.logInventory (
        report.inventory {
          presets = config.presets or { };
          tools = config.tools or { };
          gitHooks = (config.git-hooks or { }).hooks or { };
          matrix = config.stdlib.markers.ciMatrix or null;
        }
      );
      summary = report.mkEvalWarning inv;
    in
    {
      config = lib.mkIf config.stdlib.report.enable {
        warnings = [ summary ];
        enterShell = lib.mkIf config.stdlib.report.enterShell (report.mkEnterShellSnippet inv);
      };
    };

  # One root per devenv language dir under presets/, plus services/, ci/, fixtures/.
  # Missing dirs are skipped so scaffolds can land before leaves exist.
  defaultRoots =
    root:
    let
      supported = import ./devenv-supported.nix;
      existing =
        path:
        if builtins.pathExists path then
          [ path ]
        else
          [ ];
    in
    lib.concatMap (lang: existing (root + "/${lang}")) supported.languages
    ++ existing (root + "/services")
    ++ existing (root + "/ci")
    ++ existing (root + "/fixtures");
in
{
  inherit
    debtmapLanguages
    serenaLanguageServers
    surfaceOrder
    debtmapOrder
    declsOf
    refsOf
    defaultRoots
    ;

  # rootsOrAttrs: list of preset category roots (legacy) or
  # { presets = [...]; tools = [...]; }. `_*.nix` helpers skip.
  # Returns devenv modules (local tool leaves, preset options/when/requires,
  # and the project-payload lowerer). Never imports Den.
  load =
    rootsOrAttrs:
    let
      args = normalizeLoadArgs rootsOrAttrs;
      decls = declsOf args.presets;
      tools = localToolModules args.tools;
    in
    if decls == [ ] && tools == [ ] then
      [ categoryPolicy.optionsModule ]
    else
      [
        categoryPolicy.optionsModule
        (presetOptions decls)
      ]
      ++ tools
      ++ map applyPreset decls
      ++ map enablePresetTools decls
      ++ [
        lower
        reportModule
      ];
}
