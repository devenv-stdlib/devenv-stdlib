# Starship prompt. On for every terminal provider (not only Alacritty).
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
    tool = import ../../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "starship";
      category = "shell.prompt";
      install = {
        kind = "hm-program";
        program = "starship";
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
          programs.starship = {
            enable = true;
            enableBashIntegration = true;
          };
        };
      }
    )
