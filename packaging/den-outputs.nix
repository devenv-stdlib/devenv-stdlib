# Den flake body shared by this repo and by Copier-generated projects.
# `root` is the consumer tree (local modules, presets, tools).
# `stdlib` is the published devenv-stdlib attrset. The default reads ./stdlib
# from `root`, which exists in this repo and is excluded from Copier copies.
{
  inputs,
  root,
  lib ? inputs.nixpkgs.lib,
  stdlib ? import (root + "/stdlib") {
    inherit lib;
    # Private flake input — stdlib.log wraps it; callers never see nix-log.
    nix-log = inputs.nix-log or null;
  },
}:
let
  inherit (stdlib) report;

  # HM-side status summary (tools in this fixpoint). Matrix / git-hooks are
  # devenv-side; listed as unavailable here. Nested preset attrpaths land when
  # imported into denModules.
  hmReportModule =
    {
      config,
      lib,
      ...
    }:
    let
      inv = report.inventory {
        presets = config.presets or { };
        tools = config.tools or { };
        gitHooks = { };
        matrix = null;
      };
    in
    {
      warnings = lib.mkAfter [ (report.mkEvalWarning inv) ];
    };

  # Recommended Den pattern (minimal template): import-tree discovers .nix modules.
  # Scoped to Den subtrees so devenv modules under modules/ are not double-imported.
  # modules/den/_cascades/ is skipped by import-tree's default `/_` filter (pure data).
  # stdlib.den.load registers tools/** as leaf aspects (P1). Profilers stay opt-in.
  # The loader returns a list so an empty tools dir stays concatenable.
  denModules = [
    (inputs.import-tree [
      (root + "/modules/aspects")
      (root + "/modules/den")
    ])
    (
      { den, lib, ... }:
      {
        den.aspects.stdlib-report = {
          homeManager = hmReportModule;
        };
        # Append — do not replace cursor/terminal/home-cli from homes.nix.
        den.aspects.developer.includes = lib.mkAfter [ den.aspects.stdlib-report ];
      }
    )
    # Opt-in cache.mr-boxington (scope = local|global); enable defaults false.
    (root + "/presets/cache/mr-boxington.nix")
    # Opt-in cache.build-cleaner (scope = local|global); enable defaults false.
    (root + "/presets/cache/build-cleaner.nix")
  ]
  ++ (stdlib.den.load [ (root + "/tools") ]);

  denConfig = lib.evalModules {
    modules = denModules;
    specialArgs = { inherit inputs; };
  };

  den = denConfig.config.den;

  # Fixture identity for Den-only goldens (avoid impure USER/HOME drift).
  fixtureHome = {
    home.username = lib.mkForce "developer";
    home.homeDirectory = lib.mkForce "/home/developer";
  };

  # Fixture: same homes skeleton without the cursor include (cascade-off).
  denConfigNoCursor = lib.evalModules {
    modules = denModules ++ [
      (
        { den, lib, ... }:
        {
          den.aspects.developer.includes = lib.mkForce [
            den.aspects.terminal
            den.aspects.home-cli
          ];
        }
      )
    ];
    specialArgs = { inherit inputs; };
  };

  # Fixture: Warp provider XOR (terminal includes warp-quake only).
  denConfigWarp = lib.evalModules {
    modules = denModules ++ [
      (
        { den, lib, ... }:
        {
          den.aspects.terminal.includes = lib.mkForce [ den.aspects.warp-quake ];
          den.aspects.terminal.homeManager = lib.mkForce {
            imports = [ (root + "/home/terminal.nix") ];
            terminal.provider = "warp";
          };
        }
      )
    ];
    specialArgs = { inherit inputs; };
  };

  aspectIncludeNames =
    aspect: map (a: a.name or "<aspect>") denConfig.config.den.aspects.${aspect}.includes;

  # --- Phase 4: Den-only HM golden (no legacy home.nix compare) ---
  denHomeCfg =
    (denConfig.config.flake.homeConfigurations.developer.extendModules {
      modules = [ fixtureHome ];
    }).config;

  hmFingerprint =
    cfg:
    let
      pkgNames = map (p: p.pname or p.name or "<pkg>") (cfg.home.packages or [ ]);
      prog =
        name:
        let
          p = cfg.programs.${name} or { };
        in
        p.enable or false;
    in
    {
      cursorEnable = cfg.cursor.enable or false;
      llmEnable = cfg.cursor.llmContext.enable or false;
      terminalProvider = cfg.terminal.provider or null;
      programs = {
        bash = prog "bash";
        bat = prog "bat";
        starship = prog "starship";
        eza = prog "eza";
        fzf = prog "fzf";
        direnv = prog "direnv";
        zoxide = prog "zoxide";
        gh = prog "gh";
        ripgrep = prog "ripgrep";
        fd = prog "fd";
      };
      packages = lib.sort (a: b: a < b) pkgNames;
      dconfSettings = cfg.dconf.settings or { };
      systemdUserServices = builtins.attrNames (cfg.systemd.user.services or { });
    };

  denFp = hmFingerprint denHomeCfg;

  # Expected fixture goldens (developer + cursor + alacritty + home-cli).
  # fd / ripgrep ship as home.packages (not programs.*.enable).
  expectedPrograms = {
    bash = true;
    bat = true;
    starship = true;
    eza = true;
    fzf = true;
    direnv = true;
    zoxide = true;
    gh = true;
    ripgrep = false;
    fd = false;
  };

  hmGoldenOk =
    denFp.cursorEnable
    && denFp.llmEnable
    && denFp.terminalProvider == "alacritty"
    && denFp.programs == expectedPrograms
    && builtins.elem "mcp-secrets-watch" denFp.systemdUserServices
    && builtins.any (n: lib.hasPrefix "fd" n || n == "fd") denFp.packages
    && builtins.any (n: lib.hasPrefix "ripgrep" n || n == "ripgrep") denFp.packages;

  # --- Phase 4: Den/project goldens (aspect includes + pure helpers) ---
  cascade = import (root + "/modules/den/_cascades/language-cascade.nix");
  project = import (root + "/modules/lib/project.nix") { inherit lib; };
  pythonOnFixture = {
    languages.python.enable = true;
  };
  pythonGolden = {
    includes = cascade.python.includes;
    hooks = project.languageHooks pythonOnFixture;
    serena = project.serenaLanguageServers pythonOnFixture.languages;
    vscode = project.vscodeRecommendations pythonOnFixture.languages;
    debtmap = project.debtmapLanguages pythonOnFixture.languages;
  };
  expectedPythonIncludes = [
    "python-hooks"
    "python-ide-recs"
    "python-serena"
    "python-debtmap"
  ];
  projectGoldenOk =
    pythonGolden.includes == expectedPythonIncludes
    && pythonGolden.hooks.ruff
    && builtins.elem "python" pythonGolden.serena
    && builtins.elem "ms-python.python" pythonGolden.vscode
    && pythonGolden.debtmap == [ "python" ];

  # --- Project class resolve (kept from Phase 3 spike) ---
  pythonProjectModule = den.lib.aspects.resolve "project" den.aspects.python;
  pythonProjectEval = lib.evalModules {
    modules = [
      pythonProjectModule
      {
        options.denProject = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
        };
      }
    ];
  };
  pythonProjectMarkers = pythonProjectEval.config.denProject or { };
  expectedProjectConcerns = [
    "hooks"
    "ide-recs"
    "serena"
    "debtmap"
  ];

  # --- Phase 5: OS class resolve (portable shell-tools × nixos + darwin) ---
  expectedPortableTools = [
    "ripgrep"
    "fd"
    "bat"
    "fzf"
    "direnv"
    "zoxide"
  ];
  osMarkerOpts = {
    options.denOsPortable = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
    options.denOsHost = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };
  resolveOsMarkers =
    class: aspect:
    (lib.evalModules {
      modules = [
        (den.lib.aspects.resolve class aspect)
        osMarkerOpts
      ];
    }).config;
  shellToolsNixos = resolveOsMarkers "nixos" den.aspects.shell-tools;
  shellToolsDarwin = resolveOsMarkers "darwin" den.aspects.shell-tools;
  fixtureNixosMarkers = resolveOsMarkers "nixos" den.aspects.fixture-nixos;
  fixtureDarwinMarkers = resolveOsMarkers "darwin" den.aspects.fixture-darwin;

  quakeAspectKeys =
    name:
    let
      a = den.aspects.${name};
    in
    {
      hasNixos = a ? nixos;
      hasDarwin = a ? darwin;
      hasOs = a ? os;
      hasHomeManager = a ? homeManager;
    };

  hostsMatrix = {
    nixos = {
      name = "fixture-nixos";
      system = den.hosts.x86_64-linux.fixture-nixos.system;
      class = den.hosts.x86_64-linux.fixture-nixos.class;
      intoAttr = den.hosts.x86_64-linux.fixture-nixos.intoAttr;
    };
    darwin = {
      name = "fixture-darwin";
      system = den.hosts.aarch64-darwin.fixture-darwin.system;
      class = den.hosts.aarch64-darwin.fixture-darwin.class;
      intoAttr = den.hosts.aarch64-darwin.fixture-darwin.intoAttr;
    };
  };

  osClassesOk =
    shellToolsNixos.denOsPortable.aspect or null == "shell-tools"
    && shellToolsDarwin.denOsPortable.aspect or null == "shell-tools"
    && shellToolsNixos.denOsPortable.tools == expectedPortableTools
    && shellToolsDarwin.denOsPortable.tools == expectedPortableTools
    # Same payload both classes (no copy-paste): identical tool lists.
    && shellToolsNixos.denOsPortable.tools == shellToolsDarwin.denOsPortable.tools
    && hostsMatrix.nixos.class == "nixos"
    && hostsMatrix.darwin.class == "darwin"
    && hostsMatrix.nixos.intoAttr == [ ]
    && hostsMatrix.darwin.intoAttr == [ ]
    && !(quakeAspectKeys "alacritty-quake").hasNixos
    && !(quakeAspectKeys "alacritty-quake").hasDarwin
    && !(quakeAspectKeys "warp-quake").hasNixos
    && !(quakeAspectKeys "warp-quake").hasDarwin
    && !(quakeAspectKeys "terminal").hasNixos
    && !(quakeAspectKeys "terminal").hasDarwin
    && (quakeAspectKeys "alacritty-quake").hasHomeManager
    && (quakeAspectKeys "warp-quake").hasHomeManager;
in
denConfig.config.flake
// {
  # Cascade metadata + light eval helpers for tests (not HM activation).
  denCursorCascade = import (root + "/modules/den/_cascades/cursor-cascade.nix");
  denTerminalCascade = import (root + "/modules/den/_cascades/terminal-cascade.nix");
  denLanguageCascade = import (root + "/modules/den/_cascades/language-cascade.nix");
  denIdeCascade = import (root + "/modules/den/_cascades/ide-cascade.nix");
  denAspectIncludes = {
    cursor = aspectIncludeNames "cursor";
    cursor-extensions = aspectIncludeNames "cursor-extensions";
    cursor-llm = aspectIncludeNames "cursor-llm";
    terminal = aspectIncludeNames "terminal";
    alacritty-quake = aspectIncludeNames "alacritty-quake";
    warp-quake = aspectIncludeNames "warp-quake";
    home-cli = aspectIncludeNames "home-cli";
    shell-tools = aspectIncludeNames "shell-tools";
    python = aspectIncludeNames "python";
    rust = aspectIncludeNames "rust";
    go = aspectIncludeNames "go";
    javascript = aspectIncludeNames "javascript";
    typescript = aspectIncludeNames "typescript";
    project-ides = aspectIncludeNames "project-ides";
    fixture-nixos = aspectIncludeNames "fixture-nixos";
    fixture-darwin = aspectIncludeNames "fixture-darwin";
  };
  # Cursor-off fixture (still has terminal + home-cli) for cascade bats.
  homeConfigurationsNoCursor = denConfigNoCursor.config.flake.homeConfigurations or { };
  # Warp provider fixture for terminal XOR bats.
  homeConfigurationsWarp = denConfigWarp.config.flake.homeConfigurations or { };

  # Phase 4 Den-only goldens (tests).
  denHmGolden = {
    match = hmGoldenOk;
    fingerprint = denFp;
    inherit expectedPrograms;
  };
  denProjectGolden = {
    match = projectGoldenOk;
    python = pythonGolden;
    expectedIncludes = expectedPythonIncludes;
  };
  denProjectClass = {
    registered = den.classes ? project;
    pythonHub = pythonProjectMarkers.hubs.python or null;
    pythonLeafConcerns = lib.sort (a: b: a < b) (
      map (n: pythonProjectMarkers.markers.${n}.concern or "") (
        builtins.attrNames (pythonProjectMarkers.markers or { })
      )
    );
    expectedConcerns = expectedProjectConcerns;
  };

  # Phase 5 multi-OS (tests).
  denOsClasses = {
    match = osClassesOk;
    hosts = hostsMatrix;
    shellTools = {
      nixos = shellToolsNixos.denOsPortable;
      darwin = shellToolsDarwin.denOsPortable;
      expectedTools = expectedPortableTools;
    };
    hostAspects = {
      nixosIncludesShellTools = builtins.elem "shell-tools" (aspectIncludeNames "fixture-nixos");
      darwinIncludesShellTools = builtins.elem "shell-tools" (aspectIncludeNames "fixture-darwin");
      nixosHost = fixtureNixosMarkers.denOsHost or { };
      darwinHost = fixtureDarwinMarkers.denOsHost or { };
    };
    ubuntuOnlyGuards = {
      alacritty-quake = quakeAspectKeys "alacritty-quake";
      warp-quake = quakeAspectKeys "warp-quake";
      terminal = quakeAspectKeys "terminal";
    };
  };
  inherit stdlib;
  # flake output `lib` is this same stdlib attrset.
  lib = stdlib;
}
