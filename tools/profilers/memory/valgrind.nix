# GNU Valgrind (memcheck and related tools). nixpkgs attr: valgrind.
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
  (import ../../../stdlib/tool.nix { inherit lib; }).nixLeaf args {
    name = "valgrind";
    category = "profilers.memory";
    attr = "valgrind";
  }
