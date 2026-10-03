# Sampling profiler for Rust and other native binaries.
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
    name = "samply";
    category = "profilers.cpu";
    attr = "samply";
  }
