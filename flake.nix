# Den HM + cascade flake — den.homes → homeConfigurations.developer
# Sister libs (import-tree, flake-parts, den-diagram, zen, flake-aspects) intentionally omitted.
# Phase 2: terminal XOR + language/ide includes DAGs (project class still Phase 3).
{
  description = "devenv4monorepo Den Phase 2 cascades (terminal + languages + IDEs)";

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
        ./den/aspects/cursor.nix
        ./den/aspects/cursor-extensions.nix
        ./den/aspects/cursor-llm.nix
        ./den/aspects/terminal.nix
        ./den/aspects/alacritty-quake.nix
        ./den/aspects/warp-quake.nix
        ./den/aspects/languages.nix
        ./den/aspects/project-ides.nix
      ];

      denConfig = lib.evalModules {
        modules = denModules;
        specialArgs = { inherit inputs; };
      };

      # Fixture: same homes skeleton without the cursor include (cascade-off).
      denConfigNoCursor = lib.evalModules {
        modules = denModules ++ [
          (
            { den, lib, ... }:
            {
              den.aspects.developer.includes = lib.mkForce [ den.aspects.terminal ];
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
        python = aspectIncludeNames "python";
        rust = aspectIncludeNames "rust";
        go = aspectIncludeNames "go";
        javascript = aspectIncludeNames "javascript";
        typescript = aspectIncludeNames "typescript";
        project-ides = aspectIncludeNames "project-ides";
      };
      # Cursor-off fixture (still has terminal) for cascade bats.
      homeConfigurationsNoCursor = denConfigNoCursor.config.flake.homeConfigurations or { };
      # Warp provider fixture for terminal XOR bats.
      homeConfigurationsWarp = denConfigWarp.config.flake.homeConfigurations or { };
    };
}
