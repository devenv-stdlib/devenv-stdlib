# Nano plus the syntax files shipped with the package.
args@{
  pkgs,
  lib,
  config,
  ...
}:
# pkgs and config stay in the signature so Den does not call this without pkgs.
# The false branch is never evaluated; it only marks those names as used.
if false then
  { inherit pkgs config; }
else
  let
    tool = import ../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "nano";
      category = "ide";
      install = {
        kind = "nix";
        attr = "nano";
      };
      upgrade = "flake";
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
            home.packages = [ pkgs.nano ];

            # Same includes as NixOS programs.nano.syntaxHighlight: every syntax file
            # shipped with the package, including the extra/ set.
            xdg.configFile."nano/nanorc".text = ''
              include "${pkgs.nano}/share/nano/*.nanorc"
              include "${pkgs.nano}/share/nano/extra/*.nanorc"
            '';
          };
      }
    )
