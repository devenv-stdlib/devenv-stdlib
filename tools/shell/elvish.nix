# Elvish interactive shell tool. This Home Manager pin has no programs.elvish.
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
      name = "elvish";
      category = "shell";
      install = {
        kind = "nix";
        attr = "elvish";
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
        homeManager =
          { pkgs, ... }:
          {
            home.packages = [ pkgs.elvish ];
          };
      }
    )
