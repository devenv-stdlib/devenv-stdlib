{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  # Owner suite: load only this leaf (discover on tools/<…>/<name>/ is empty — tests/ skipped).
  discovered = stdlib.mkTool.specs [ <devenv4monorepo/tools/profilers/memory/cargo-valgrind.nix> ];
  byName = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
  cargoValgrind = byName."cargo-valgrind".spec;
in
{
  testStdlibCargoValgrindDependsOnValgrind = {
    expr = {
      inherit (cargoValgrind) category dependsOn;
      inherit (cargoValgrind.install) attr;
    };
    expected = {
      category = "profilers.memory";
      attr = "cargo-valgrind";
      dependsOn = [ "valgrind" ];
    };
  };
}
