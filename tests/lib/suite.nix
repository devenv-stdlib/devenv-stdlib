# Load every topic `*.nix` in a suite directory into one nix-unit attrset.
# Skips default.nix (the suite entry) and harness.nix.
{ lib }:
let
  harness = import ./harness.nix { inherit lib; };
in
{
  load =
    suiteDir:
    let
      entries = builtins.readDir suiteDir;
      skip = [
        "default.nix"
        "harness.nix"
      ];
      topics = lib.filter (
        name: entries.${name} == "regular" && lib.hasSuffix ".nix" name && !(builtins.elem name skip)
      ) (lib.sort (a: b: a < b) (builtins.attrNames entries));
    in
    lib.foldl' (acc: name: acc // (import (suiteDir + "/${name}") harness)) { } topics;
}
