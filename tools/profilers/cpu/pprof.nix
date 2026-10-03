# Go pprof viewer. Not a debugger.
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
    name = "pprof";
    category = "profilers.cpu";
    attr = "pprof";
  }
