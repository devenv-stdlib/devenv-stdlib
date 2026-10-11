# Local git-hooks leaf: reject Python debug leftovers.
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
      name = "debug-statements";
      category = "lang.python";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project.git-hooks.hooks.python-debug-statements.enable = true;
    };
  in
  if args.__stdlibMeta or false then tool.meta spec else tool.applyLocal args spec
