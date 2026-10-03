# Local Astral ty type-checker git-hook leaf.
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
      name = "ty";
      category = "lang.python.linters";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project =
        { pkgs, ... }:
        {
          git-hooks.hooks.ty = {
            enable = true;
            name = "ty";
            description = "Astral ty type checker (beta)";
            package = pkgs.ty;
            entry = "${pkgs.ty}/bin/ty check";
            files = "\\.py$";
          };
        };
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.applyLocal args spec
