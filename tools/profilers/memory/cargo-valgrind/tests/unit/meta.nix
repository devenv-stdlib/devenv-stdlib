{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  discovered = stdlib.mkTool.specs (stdlib.discover [ <devenv4monorepo/tools> ]);
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
