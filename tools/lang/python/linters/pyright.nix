# Local pyright git-hook leaf.
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
    tool = import ../../../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "pyright";
      category = "lang.python.linters";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project.git-hooks.hooks.pyright.enable = true;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.applyLocal args spec
