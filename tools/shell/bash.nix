# Bash interactive shell tool. Ubuntu bashrc.d layout stays in home/bash.nix.
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
      name = "bash";
      category = "shell";
      install = {
        kind = "hm-program";
        program = "bash";
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
          programs.bash = {
            enable = true;
            enableCompletion = true;
          };
        };
      }
    )
