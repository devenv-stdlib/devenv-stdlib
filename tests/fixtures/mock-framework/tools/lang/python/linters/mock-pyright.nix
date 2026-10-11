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
    inherit ((import ../../../../lib.nix { inherit lib; })) tool;
    spec = {
      name = "mock-pyright";
      category = "lang.python.linters";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project = {
        git-hooks.hooks.mock-pyright.enable = true;
      };
    };
  in
  if args.__stdlibMeta or false then tool.meta spec else tool.applyLocal args spec
