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
      name = "mock-ext";
      category = "ide";
      install = {
        kind = "vscode-extension";
        publisher = "mock";
        extension = "mock-ext";
        registry = "open-vsx";
      };
      upgrade = "catalog";
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
