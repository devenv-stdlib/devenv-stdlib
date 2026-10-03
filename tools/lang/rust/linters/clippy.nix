# Local clippy git-hook leaf.
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
      name = "clippy";
      category = "lang.rust.linters";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project.git-hooks.hooks.clippy.enable = true;
    };
  in
  if args.__stdlibMeta or false then tool.meta spec else tool.applyLocal args spec
