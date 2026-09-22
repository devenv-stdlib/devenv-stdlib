# Den HM + cascade flake — den.homes → homeConfigurations.developer
# Sister libs (import-tree, flake-parts, den-diagram, zen, flake-aspects) intentionally omitted.
# Phase 4: cutover — Den-only home-switch; dual shims deleted; Den-only goldens.
{
  description = "devenv4monorepo Den Phase 4 cutover (Den-only HM + project goldens)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pinned release — sole composition dependency (den only).
    den.url = "github:denful/den/v0.18.0";
  };

  outputs =
    inputs:
    let
      lib = inputs.nixpkgs.lib;

      denModules = [
        ./den/homes.nix
        ./den/classes/project.nix
        ./den/aspects/cursor.nix
        ./den/aspects/cursor-extensions.nix
        ./den/aspects/cursor-llm.nix
        ./den/aspects/terminal.nix
        ./den/aspects/alacritty-quake.nix
        ./den/aspects/warp-quake.nix
        ./den/aspects/home-cli.nix
        ./den/aspects/languages.nix
        ./den/aspects/project-ides.nix
      ];

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
                imports = [ ./home/terminal.nix ];
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
      cascade = import ./den/language-cascade.nix;
      project = import ./modules/lib/project.nix { inherit lib; };
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
    in
    denConfig.config.flake
    // {
      # Cascade metadata + light eval helpers for tests (not HM activation).
      denCursorCascade = import ./den/cursor-cascade.nix;
      denTerminalCascade = import ./den/terminal-cascade.nix;
      denLanguageCascade = import ./den/language-cascade.nix;
      denIdeCascade = import ./den/ide-cascade.nix;
      denAspectIncludes = {
        cursor = aspectIncludeNames "cursor";
        cursor-extensions = aspectIncludeNames "cursor-extensions";
        cursor-llm = aspectIncludeNames "cursor-llm";
        terminal = aspectIncludeNames "terminal";
        alacritty-quake = aspectIncludeNames "alacritty-quake";
        warp-quake = aspectIncludeNames "warp-quake";
        home-cli = aspectIncludeNames "home-cli";
        python = aspectIncludeNames "python";
        rust = aspectIncludeNames "rust";
        go = aspectIncludeNames "go";
        javascript = aspectIncludeNames "javascript";
        typescript = aspectIncludeNames "typescript";
        project-ides = aspectIncludeNames "project-ides";
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
    };
}
