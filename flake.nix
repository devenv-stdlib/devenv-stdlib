# Den HM spike flake — den.homes → homeConfigurations.developer
# Sister libs (import-tree, flake-parts, den-diagram, zen, flake-aspects) intentionally omitted.
{
  description = "devenv4monorepo Den Phase 1 HM spike (cursor cascade)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pinned release — sole composition dependency for this spike.
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
      ];

      denConfig = lib.evalModules {
        modules = denModules;
        specialArgs = { inherit inputs; };
      };

      # Fixture: same homes skeleton without the cursor include (cascade-off).
      denConfigNoCursor = lib.evalModules {
        modules = denModules ++ [
          (
            { lib, ... }:
            {
              den.aspects.developer.includes = lib.mkForce [ ];
            }
          )
        ];
        specialArgs = { inherit inputs; };
      };
    in
    denConfig.config.flake
    // {
      # Expose cascade metadata + light eval helpers for tests (not HM activation).
      denCursorCascade = import ./den/cursor-cascade.nix;
      denAspectIncludes = {
        cursor = map (a: a.name or "<aspect>") denConfig.config.den.aspects.cursor.includes;
        cursor-extensions = map (
          a: a.name or "<aspect>"
        ) denConfig.config.den.aspects.cursor-extensions.includes;
        cursor-llm = map (a: a.name or "<aspect>") denConfig.config.den.aspects.cursor-llm.includes;
      };
      # Cursor-off fixture homeConfigurations for cascade bats.
      homeConfigurationsNoCursor = denConfigNoCursor.config.flake.homeConfigurations or { };
    };
}
