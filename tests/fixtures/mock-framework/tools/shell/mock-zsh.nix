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
    inherit ((import ../../lib.nix { inherit lib; })) tool;
    spec = {
      name = "mock-zsh";
      category = "shell";
      install = {
        kind = "nix";
        attr = "zsh";
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
        homeManager = _: { };
      }
    )
