# Neovim on PATH. Plugins are a later TODO.
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
        program = "neovim";
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
          programs.neovim = {
            enable = true;
            # Adopt the 26.05 defaults now so providers are not pulled in unused.
            withRuby = false;
            withPython3 = false;
          };
        };
      }
    )
