# Neovim via nix-community/nixvim (programs.nixvim). Minimal enable — compose
# plugins/LSP with nixvim modules in home.local.nix or a follow-up preset.
args@{
  pkgs,
  lib,
  config,
  ...
}:
# pkgs and config stay in the signature so Den does not call this without pkgs.
# The false branch is never evaluated; it only marks those names as used.
if false then
  { inherit pkgs config; }
else
  let
    tool = import ../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "neovim";
      category = "ide";
      install = {
        kind = "hm-program";
        # nixvim's Home Manager module (inputs.nixvim.homeModules.nixvim).
        program = "nixvim";
      };
      upgrade = "flake";
      defaultEnable = true;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.apply args (
      spec
      // {
        homeManager = _: {
          # Module import lives on den.aspects.home-cli (inputs available there).
          # Incompatible with programs.neovim.enable — nixvim asserts that.
          programs.nixvim = {
            enable = true;
            # Match prior programs.neovim wiring: do not pull unused providers.
            withRuby = false;
            withPython3 = false;
          };
        };
      }
    )
