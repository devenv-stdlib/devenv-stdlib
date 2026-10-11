# Local gofmt git-hook leaf.
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
      name = "gofmt";
      category = "lang.go.linters";
      install = {
        kind = "project";
      };
      upgrade = "none";
      # Format via devenv treefmt (git-hooks.hooks.treefmt runs the suite).
      project.treefmt.config.programs.gofmt.enable = true;
    };
  in
  if args.__stdlibMeta or false then tool.meta spec else tool.applyLocal args spec
