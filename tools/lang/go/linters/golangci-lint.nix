# Local golangci-lint git-hook leaf.
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
      name = "golangci-lint";
      category = "lang.go.linters";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project.git-hooks.hooks.golangci-lint.enable = true;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.applyLocal args spec
