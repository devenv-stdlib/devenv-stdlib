{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  discovered = stdlib.mkTool.specs (stdlib.discover [ <devenv4monorepo/tools> ]);
  byName = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
  valgrind = byName.valgrind.spec;
in
{
  testStdlibValgrindInstall = {
    expr = {
      inherit (valgrind) category upgrade;
      inherit (valgrind.install) attr kind;
    };
    expected = {
      category = "profilers.memory";
      attr = "valgrind";
      kind = "nix";
      upgrade = "flake";
    };
  };
}
