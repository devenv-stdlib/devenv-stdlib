# Local git-hooks leaf: sort requirements.txt.
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
      name = "sort-requirements-txt";
      category = "lang.python";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project.git-hooks.hooks.sort-requirements-txt.enable = true;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.applyLocal args spec
