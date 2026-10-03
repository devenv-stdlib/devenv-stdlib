# cargo-valgrind: cargo subcommand that runs valgrind.
# nixpkgs attr `cargo-valgrind` (pkgs/by-name/ca/cargo-valgrind) wraps
# valgrind onto PATH. Enabling this leaf also enables the valgrind tool.
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
    name = "cargo-valgrind";
    category = "profilers.memory";
    attr = "cargo-valgrind";
    dependsOn = [ "valgrind" ];
  }
