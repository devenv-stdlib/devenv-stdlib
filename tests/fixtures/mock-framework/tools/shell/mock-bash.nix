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
    tool = (import ../../lib.nix { inherit lib; }).tool;
    spec = {
      name = "mock-bash";
      category = "shell";
      install = {
        kind = "nix";
        attr = "bash";
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
        homeManager = _: { };
      }
    )
