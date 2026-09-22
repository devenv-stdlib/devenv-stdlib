# Den HM + cascade flake — den.homes → homeConfigurations.developer
# Sister libs (import-tree, flake-parts, den-diagram, zen, flake-aspects) intentionally omitted.
# Phase 3: dual-run HM/project parity + custom project class spike (devenv CLI unchanged).
{
  description = "devenv4monorepo Den Phase 3 dual-run (HM/project parity + project class)";

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
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs.legacyPackages.${system};

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

      # Fixture identity for dual HM parity (avoid impure USER/HOME drift).
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

      # --- Phase 3: dual HM evaluation (Den vs legacy home.nix) ---
      # Den path: extend the flake homeConfiguration with a fixed fixture identity.
      denHomeCfg =
        (denConfig.config.flake.homeConfigurations.developer.extendModules {
          modules = [ fixtureHome ];
        }).config;

      # Legacy path: same nixpkgs + HM + fixture identity as Den.
      legacyHomeCfg =
        (inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./home.nix
            fixtureHome
            {
              # Match den.default.homeManager allowUnfree.
              nixpkgs.config.allowUnfree = true;
            }
          ];
        }).config;

      # Normalized fingerprint for dual-run parity (packages / programs / dconf / units).
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
          # Sorted package names — order must not affect parity.
          packages = lib.sort (a: b: a < b) pkgNames;
          # dconf keys of interest (terminal GNOME bindings live here when set).
          dconfSettings = cfg.dconf.settings or { };
          # User systemd units of interest (mcp-secrets-watch).
          systemdUserServices = builtins.attrNames (cfg.systemd.user.services or { });
        };

      denFp = hmFingerprint denHomeCfg;
      legacyFp = hmFingerprint legacyHomeCfg;

      hmParity = {
        cursorEnable = denFp.cursorEnable == legacyFp.cursorEnable;
        llmEnable = denFp.llmEnable == legacyFp.llmEnable;
        terminalProvider = denFp.terminalProvider == legacyFp.terminalProvider;
        programs = denFp.programs == legacyFp.programs;
        packages = denFp.packages == legacyFp.packages;
        # systemd unit names (sorted compare)
        systemdUserServices =
          (lib.sort (a: b: a < b) denFp.systemdUserServices)
          == (lib.sort (a: b: a < b) legacyFp.systemdUserServices);
      };

      hmParityOk = builtins.all (v: v) (builtins.attrValues hmParity);

      # --- Phase 3: project class resolve spike ---
      projectBridge = import ./modules/lib/den-project-bridge.nix { inherit lib; };

      # Resolve python aspect's project class into a plain module (NVF-style).
      pythonProjectModule = den.lib.aspects.resolve "project" den.aspects.python;

      # Stub options so resolve output can be evaluated without full devenv.
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

      # Phase 3 dual-run exports (tests).
      denHmParity = {
        match = hmParityOk;
        checks = hmParity;
        den = denFp;
        legacy = legacyFp;
      };
      denProjectParity = {
        match = projectBridge.pythonParityMatch;
        aspect = projectBridge.aspectPythonParity;
        legacy = projectBridge.legacyPythonParity;
      };
      denProjectClass = {
        registered = den.classes ? project;
        pythonHub = pythonProjectMarkers.hubs.python or null;
        pythonLeafConcerns = lib.sort (a: b: a < b) (
          map (n: pythonProjectMarkers.markers.${n}.concern or "") (
            builtins.attrNames (pythonProjectMarkers.markers or { })
          )
        );
        expectedConcerns = projectBridge.expectedProjectMarkers.python.concerns;
      };
    };
}
