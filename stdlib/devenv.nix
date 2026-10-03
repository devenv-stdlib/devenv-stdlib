# Plain devenv loader. Do not import Den here: devenv evaluation must not
# fetch Den (that is the #22 CI failure surface). Den lowering lives in
# stdlib.den.load, which P2 owns.
{ lib }:
let
  presetApi = import ./preset.nix { inherit lib; };
  projectLib = import ../modules/lib/project.nix { inherit lib; };

  # Selected-pack order matches modules/ides (rust, go, python, then the
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

  collect =
    dir:
    let
      entries = builtins.readDir dir;
      names = lib.sort (a: b: a < b) (builtins.attrNames entries);
      files = lib.filter (
        name: entries.${name} == "regular" && lib.hasSuffix ".nix" name && !(lib.hasPrefix "_" name)
      ) names;
      dirs = lib.filter (name: entries.${name} == "directory" && !(lib.hasPrefix "_" name)) names;
    in
    map (name: dir + "/${name}") files ++ lib.concatMap (name: collect (dir + "/${name}")) dirs;

  isPreset = value: value._type or null == "devenv-preset";

  loadFile =
    file:
    let
      decl = import file {
        inherit lib;
        stdlib = presetApi;
      };
    in
    if isPreset decl then
      decl
    else
      throw "stdlib.devenv.load: ${toString file} must return stdlib.mkPreset";

  declsOf =
    roots:
    let
      files = lib.concatMap collect roots;
      decls = map loadFile files;
      names = map (decl: decl.name) decls;
      dupes = lib.filter (name: lib.count (x: x == name) names > 1) (lib.unique names);
    in
    if dupes != [ ] then
      throw "stdlib.devenv.load: duplicate preset names: ${toString dupes}"
    else
      decls;

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

  presetOptions =
    decls:
    { config, ... }:
    {
      options = {
        presets = {
          strict = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              When true, unmet preset requires fail evaluation.
              When false, devenv warns and leaves the preset inert.
              presets.<name>.strict overrides this per preset.
            '';
          };
        }
        // lib.genAttrs (map (decl: decl.name) decls) (name: {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Apply the ${name} preset when its when condition holds.";
          };
          strict = lib.mkOption {
            type = lib.types.bool;
            default = config.presets.strict;
            description = "Unmet requires throw. Set false to warn and skip ${name}.";
          };
        });

        stdlib.lang = lib.mkOption {
          type = lib.types.attrsOf langType;
          default = { };
          description = ''
            Language-preset contributions. stdlib.devenv.load lowers these into
            Serena, editor recommendations, debtmap, and CI matrix flags.
          '';
        };

        stdlib.markers = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          internal = true;
          description = "Exemplar markers for fixture presets. Not a public API.";
        };
      };
    };

  applyPreset =
    decl:
    {
      config,
      lib,
      pkgs ? { },
      ...
    }:
    let
      enabled = config.presets.${decl.name}.enable;
      triggered = decl.when config;
      strict = config.presets.${decl.name}.strict;
      reqOk = req: if lib.isFunction req.assertion then req.assertion config else req.assertion;
      reqsOk = lib.all reqOk decl.requires;
      active = enabled && triggered && reqsOk;
      failed = lib.filter (req: !reqOk req) decl.requires;
    in
    {
      imports = lib.optional (decl.module != null) decl.module;
      config = lib.mkMerge [
        {
          assertions = lib.optionals (enabled && triggered && strict) (
            map (req: {
              assertion = reqOk req;
              inherit (req) message;
            }) decl.requires
          );
          warnings = lib.optionals (enabled && triggered && !strict) (map (req: req.message) failed);
        }
        (lib.mkIf active (
          if lib.isFunction decl.project then
            decl.project {
              inherit
                config
                lib
                pkgs
                ;
            }
          else
            decl.project
        ))
      ];
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
in
{
  inherit
    debtmapLanguages
    serenaLanguageServers
    surfaceOrder
    debtmapOrder
    ;

  # roots: list of directories. `_*.nix` files are helpers, not presets.
  # Returns devenv modules (options, per-preset when/requires, and the
  # project-payload lowerer). Never imports Den.
  load =
    roots:
    let
      decls = declsOf roots;
    in
    [
      (presetOptions decls)
    ]
    ++ map applyPreset decls
    ++ [ lower ];
}
