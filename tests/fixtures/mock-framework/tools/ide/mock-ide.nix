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
      name = "mock-ide";
      category = "ide";
      install = {
        kind = "hm-program";
        program = "mock-ide";
      };
      upgrade = "self";
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
