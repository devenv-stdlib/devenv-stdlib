# CodeRabbit CLI (official zip). Packaged in stdlib/coderabbit-cli.nix — not nixpkgs.
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
    tool = import ../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "coderabbit-cli";
      category = "ide";
      install = {
        # In-repo binary package (stdlib/coderabbit-cli.nix), not a nixpkgs attr.
        kind = "binary";
      };
      # CLI ships `coderabbit update`; pin bumps are manual in stdlib/coderabbit-cli.nix.
      upgrade = "self";
      defaultEnable = true;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.apply args (
      spec
      // {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = [ (import ../../stdlib/coderabbit-cli.nix { inherit pkgs; }) ];
          };
      }
    )
