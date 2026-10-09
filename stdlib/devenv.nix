# Plain devenv loader. Do not import Den here: devenv evaluation must not
# fetch Den. Condition checks go through realize in stdlib/preset.nix.
# mkPreset's Den aspect module is not imported into this evaluator.
#
# Preset identity is a nested attrpath mirroring tool categories
# (python.lint.ruff), not a flat string name.
#
# Tool inclusion uses the same attrpath style (python.lint.pyright), via
# tool-ref values from refsOfTools / mkTool.refsFromSpecs. Enable options
# stay at tools.<leaf>.enable; global vs local is an internal payload split.
#
# Tools may declare devenv task leaves (`tasks` on mkTool). Local tools lower
# them on enable. Thin presets may `exportTasks` (tool refs) and `workflows`
# (compose before/after around an anchor) — see stdlib/tasks.nix.
#
# Logging goes through stdlib.log (nix-log is private). End-of-eval report
# uses module warnings + enterShell — no wrapper scripts. Tracked generated
# files are tasks + enterShell dry-run, not enterShell writers.
#
# Local mkTool leaves (project payload) live under tools/** and are lowered
# here via applyLocal. Thin presets list tool attrpath refs; when applied
# they set tools.<leaf>.enable = true.
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
  tasksLib = import ./tasks.nix { inherit lib; };
  loadLib = import ./load.nix { inherit lib; };
  categoryPolicy = import ./category-policy.nix { inherit lib; };
  projectLib = import ../modules/lib/project.nix { inherit lib; };
  log = import ./log.nix { inherit lib nix-log; };
  report = import ./report.nix { inherit lib log; };
  generate = import ./generate.nix { inherit lib; };
  categoryWarnings = import ./category-warnings.nix { inherit lib; };

  generatedFileType = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        description = "Path relative to DEVENV_ROOT of a generated tracked file.";
      };
      task = lib.mkOption {
        type = lib.types.str;
        description = "devenv task that writes this file.";
      };
      script = lib.mkOption {
        type = lib.types.str;
        description = "PATH command that writes this file (honors --dry-run).";
      };
      source = lib.mkOption {
        type = lib.types.anything;
        default = "";
        description = "Nix store path of the desired contents (mode = copy).";
      };
      mode = lib.mkOption {
        type = lib.types.enum [
          "copy"
          "ensure-newline"
        ];
        default = "copy";
        description = ''
          copy: replace the file with source bytes.
          ensure-newline: leave contents in place; only add a trailing newline.
        '';
      };
    };
  };

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
      # Skip colocated tests/ suites (tools|presets/**/tests/{unit,integration}).
      dirs = lib.filter (
        name: entries.${name} == "directory" && !(lib.hasPrefix "_" name) && name != "tests"
      ) names;
    in
    # default.nix is the directory attrpath (presets/ide/default.nix → ide).
    # Any other file adds its stem (presets/ide/neovim.nix → ide.neovim).
    map (
      name:
      let
        segment = lib.removeSuffix ".nix" name;
      in
      {
        file = root + "/${name}";
        path = if segment == "default" then prefix else prefix ++ [ segment ];
      }
    ) files
    ++ lib.concatMap (name: collect (root + "/${name}") (prefix ++ [ name ])) dirs;

  isPreset =
    value:
    builtins.isAttrs value
    && ((value ? path && builtins.isList value.path) || (value ? name && builtins.isString value.name));

  loadEntry =
    entry: tools:
    let
      decl = import entry.file {
        inherit lib tools;
      };
      # File location is identity for refsOf (no import). Declared path must match.
      presetPath =
        if decl ? path then
          let
            declared = presetLib.normalizePath decl.path;
          in
          if declared != entry.path then
            throw "stdlib.devenv.load: ${toString entry.file} path ${presetLib.pathString declared} does not match file location ${presetLib.pathString entry.path}"
          else
            declared
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

  refsOfTools = toolRoots: toolLib.refsFromSpecs (toolLib.specs (loadLib.discover toolRoots));

  declsOf =
    roots: tools:
    let
      entries = lib.concatMap (
        root:
        let
          base = baseNameOf (toString root);
        in
        collect root [ base ]
      ) roots;
      decls = map (entry: loadEntry entry tools) entries;
      ids = map (decl: decl.name) decls;
      dupes = lib.filter (id: lib.count (x: x == id) ids > 1) (lib.unique ids);
    in
    if dupes != [ ] then
      throw "stdlib.devenv.load: duplicate preset attrpaths: ${toString dupes}"
    else
      decls;

  # Nested preset refs from directory layout (no import — thin presets need tools).
  # loadEntry rejects declared paths that diverge from this filesystem identity.
  refsOf =
    roots:
    presetLib.refsFromPaths (
      map (entry: entry.path) (
        lib.concatMap (
          root:
          let
            base = baseNameOf (toString root);
          in
          collect root [ base ]
        ) roots
      )
    );

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
        # Opt-in presets set defaultEnable = false on the thin declaration.
        default = decl.defaultEnable or true;
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
    }
    # Declarations may add options beside enable/strict/result
    # (presets.terminal.quake.provider). Tool selection reads them during realize.
    // (decl.extraOptions or { });

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

          generated = lib.mkOption {
            type = lib.types.listOf generatedFileType;
            default = [ ];
            description = ''
              Git-tracked files produced by stdlib generators. enterShell dry-runs
              these (no writes) and the status report names the update task when
              a file is stale. `devenv tasks run stdlib:update-generated` writes
              all of them.
            '';
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
    decl: discoveredTools:
    {
      config,
      lib,
      pkgs ? { },
      options,
      ...
    }@moduleArgs:
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
              options
              ;
          }
        else
          decl.project;
      # Presets export tool-declared tasks and/or compose workflow edges.
      # Only when the host declares options.tasks (devenv); fixtures may omit it.
      #
      # Do NOT gate on `logged.applied` inside this let: the value is wrapped in
      # `mkIf logged.applied` below, and pushDownProperties forces `content`.
      # Re-checking `logged.applied` here re-enters realize → config → cycle
      # (infinite recursion / Failed to get attribute 'config.cachix.enable').
      # exportTasks / workflows must be static lists (or not read `config`);
      # scope-gated exports belong in the preset `module` mkIf, like packages.
      taskConfig =
        if !(tasksLib.hostHasTasks moduleArgs) then
          { }
        else
          let
            exported = tasksLib.export {
              items = decl.exportTasks or [ ];
              discovered = discoveredTools;
              inherit moduleArgs;
            };
            composed = tasksLib.workflows (decl.workflows or [ ]);
            # Concatenate before/after; do not drop exported edges under composed ones.
            merged = tasksLib.mergeEdges [
              exported
              composed
            ];
          in
          # Static key (see tool.applyLocal): a non-applied preset must not
          # evaluate its exports.
          {
            tasks = merged;
          };
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
        (lib.mkIf logged.applied taskConfig)
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

  # List-form load [ presets/<lang> … ] still needs tool refs for thin presets
  # (`tools = [ tools.rust.lint.clippy ]`). Infer …/tools beside …/presets.
  inferToolsFromPresetRoots =
    presetRoots:
    lib.unique (
      lib.concatMap (
        root:
        let
          presetsDir = dirOf (toString root);
          repoDir = dirOf presetsDir;
          toolsDir = repoDir + "/tools";
        in
        if builtins.baseNameOf presetsDir == "presets" && builtins.pathExists toolsDir then
          [ toolsDir ]
        else
          [ ]
      ) presetRoots
    );

  normalizeLoadArgs =
    rootsOrAttrs:
    if builtins.isList rootsOrAttrs then
      {
        presets = rootsOrAttrs;
        tools = inferToolsFromPresetRoots rootsOrAttrs;
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
      options,
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
      extensionsJson = builtins.toFile "extensions.json" (
        generate.ensureTrailingNewline (
          builtins.toJSON {
            inherit recommendations unwantedRecommendations;
          }
        )
      );
      settingsJson = builtins.toFile "settings.json" (
        generate.ensureTrailingNewline (builtins.toJSON settings)
      );
    in
    {
      config = lib.mkMerge [
        {
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

          # Internal: lets fixture tests see merged editor settings without
          # evaluating the extension symlink script (that needs nixpkgs).
          stdlib.markers.ideSettings = settings;

          stdlib.generated = [
            {
              path = ".vscode/extensions.json";
              task = "ides:update-extensions-json";
              script = "sync-vscode-extensions-json";
              source = extensionsJson;
            }
            {
              path = ".vscode/settings.json";
              task = "ides:update-settings-json";
              script = "sync-vscode-settings-json";
              source = settingsJson;
            }
          ];

          scripts.sync-vscode-extensions-json.exec = generate.mkSyncFileExec {
            storePath = extensionsJson;
            relPath = ".vscode/extensions.json";
          };
          scripts.sync-vscode-settings-json.exec = generate.mkSyncFileExec {
            storePath = settingsJson;
            relPath = ".vscode/settings.json";
          };

          # Package symlinks stay lazy so unit tests can read files without nixpkgs.
          # Home-dir links only; tracked .vscode JSON is the generate tasks above.
          scripts.cursor-sync-extensions.exec = idesLib.mkSyncScript {
            extensionsDir = "$HOME/.cursor/extensions";
            logPrefix = "cursor";
            inherit selected;
          };
          scripts.vscode-sync-extensions.exec = idesLib.mkSyncScript {
            extensionsDir = "$HOME/.vscode/extensions";
            logPrefix = "ides";
            inherit selected;
          };

          enterShell = ''
            cursor-sync-extensions
          '';
        }
        # mkIf false still defines `tasks` and breaks fixtures without that option.
        (lib.optionalAttrs (options ? tasks) {
          tasks."ides:update-extensions-json".exec = generate.mkSyncFileExec {
            storePath = extensionsJson;
            relPath = ".vscode/extensions.json";
          };
          tasks."ides:update-settings-json".exec = generate.mkSyncFileExec {
            storePath = settingsJson;
            relPath = ".vscode/settings.json";
          };
        })
      ];
    };

  # Sequential writer for every stdlib.generated entry (PATH scripts, in order).
  generatedTasksModule =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      files = config.stdlib.generated or [ ];
      body =
        if files == [ ] then
          "true"
        else
          ''
            set -euo pipefail
            status=0
            ${lib.concatMapStringsSep "\n" (g: ''
              echo "==> ${g.task} (${g.path})"
              if ! ${g.script} "$@"; then
                status=1
              fi
            '') files}
            exit "$status"
          '';
    in
    {
      # mkIf false still defines `tasks`; omit the attr when the option is absent.
      config = lib.optionalAttrs (options ? tasks) {
        tasks."stdlib:update-generated".exec = body;
      };
    };

  # Forced summary after all presets realize. warnings = end of eval;
  # enterShell = Nix-built echo (not a wrapper script) plus generated-file dry-run.
  reportModule =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      toolsCfg = if options ? tools then config.tools else { };
      unusedCategories =
        if config.stdlib.categoryWarnings.enable or true then
          categoryWarnings.unusedPaths {
            inherit config;
            tools = config.stdlib.categoryWarnings.toolIndex or [ ];
            presets = config.presets or { };
          }
        else
          [ ];
      inv =
        let
          raw = report.logInventory (
            report.inventory {
              presets = config.presets or { };
              tools = toolsCfg;
              gitHooks = (config.git-hooks or { }).hooks or { };
              treefmtPrograms = ((config.treefmt or { }).config or { }).programs or { };
              matrix = config.stdlib.markers.ciMatrix or null;
              generated = config.stdlib.generated or [ ];
              inherit unusedCategories;
            }
          );
        in
        # Force stdlib.log warn when available categories are unused.
        if unusedCategories == [ ] then
          raw
        else
          log.warn' "unused available categories" {
            count = builtins.length unusedCategories;
            paths = unusedCategories;
          } raw;
      summary = report.mkEvalWarning inv;
    in
    {
      config = lib.mkIf config.stdlib.report.enable {
        warnings = [ summary ];
        enterShell = lib.mkIf config.stdlib.report.enterShell (report.mkEnterShellSnippet inv);
      };
    };

  # One root per devenv language dir under presets/, plus services/, ci/,
  # fixtures/, cache/ (compile-cache / cleaner presets such as mr-boxington),
  # and ide/, host/, and terminal/ (not devenv language names). Missing dirs are skipped so
  # scaffolds can land before leaves exist.
  defaultRoots =
    root:
    let
      supported = import ./devenv-supported.nix;
      existing = path: if builtins.pathExists path then [ path ] else [ ];
    in
    lib.concatMap (lang: existing (root + "/${lang}")) supported.languages
    ++ existing (root + "/services")
    ++ existing (root + "/ci")
    ++ existing (root + "/fixtures")
    ++ existing (root + "/cache")
    ++ existing (root + "/ide")
    ++ existing (root + "/host")
    ++ existing (root + "/terminal");
in
{
  inherit
    debtmapLanguages
    serenaLanguageServers
    surfaceOrder
    debtmapOrder
    declsOf
    refsOf
    refsOfTools
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
      toolRefs = refsOfTools args.tools;
      decls = declsOf args.presets toolRefs;
      discoveredTools = toolLib.specs (loadLib.discover args.tools);
      toolModules = localToolModules args.tools;
    in
    if decls == [ ] && toolModules == [ ] then
      [
        categoryPolicy.optionsModule
        categoryWarnings.optionsModule
        categoryWarnings.module
      ]
    else
      [
        categoryPolicy.optionsModule
        categoryWarnings.optionsModule
        (presetOptions decls)
      ]
      ++ toolModules
      ++ map (decl: applyPreset decl discoveredTools) decls
      ++ map enablePresetTools decls
      ++ [
        lower
        categoryWarnings.module
        generatedTasksModule
        reportModule
      ];
}
