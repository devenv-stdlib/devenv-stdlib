# Zsh interactive shell tool.
args@{
  pkgs,
  lib,
  config,
  ...
}:
if false then
  { inherit pkgs config; }
else
  let
    tool = import ../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "zsh";
      category = "shell";
      install = {
        kind = "hm-program";
        program = "zsh";
      };
      upgrade = "flake";
      defaultEnable = false;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.apply args (
      spec
      // {
        homeManager = _: {
          programs.zsh = {
            enable = true;
            enableCompletion = true;
          };
        };
      }
    )
