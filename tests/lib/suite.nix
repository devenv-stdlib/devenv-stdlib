# Load every topic `*.nix` in a suite directory into one nix-unit attrset.
# Skips default.nix (the suite entry) and harness.nix.
{ lib }:
let
  harness = import ./harness.nix { inherit lib; };

  # Merge topic attrsets; throw if two topics define the same test name.
  mergeTests =
    label: acc: next:
    let
      dups = lib.intersectLists (builtins.attrNames acc) (builtins.attrNames next);
    in
    if dups != [ ] then
      throw "suite.load: duplicate tests in ${label}: ${lib.concatStringsSep ", " dups}"
    else
      acc // next;
in
{
  inherit mergeTests;

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
    lib.foldl' (
      acc: name: mergeTests "${toString suiteDir}/${name}" acc (import (suiteDir + "/${name}") harness)
    ) { } topics;
}
