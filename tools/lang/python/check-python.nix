# Local git-hooks check-python leaf.
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
    tool = import ../../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "check-python";
      category = "lang.python";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project.git-hooks.hooks.check-python.enable = true;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.applyLocal args spec
