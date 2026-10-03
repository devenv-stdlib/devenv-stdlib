# Den HM + cascade flake — den.homes → homeConfigurations.developer
# Layout: modules/aspects + modules/den via import-tree (devenv stays on modules/devenv.nix).
# Phase 5 tip + import-tree unify: multi-OS stubs unchanged; no effects/zen.
# Publishable framework: outputs.stdlib and outputs.lib are one devenv-stdlib attrset.
# Copier-generated flakes take that attrset from a GitHub input (see consumer-flake.nix.jinja).
{
  description = "devenv4monorepo Den + import-tree modules unify";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pinned release — composition dependency.
    den.url = "github:denful/den/v0.18.0";
    # Den templates / battery companion — scoped discovery of modules/{aspects,den}.
    import-tree.url = "github:denful/import-tree/v0.2.0";
    # Private backend for stdlib.log (not part of the public stdlib API).
    nix-log.url = "github:rvolosatovs/nix-log";
    # Neovim configuration — tools/ide/neovim.nix enables programs.nixvim.
    # Do not follows nixpkgs: nixvim is tested against its own pin.
    nixvim.url = "github:nix-community/nixvim";
  };

  outputs =
    inputs:
    import ./packaging/den-outputs.nix {
      inherit inputs;
      root = ./.;
    };
}
