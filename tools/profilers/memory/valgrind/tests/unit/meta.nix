{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  # Owner suite: load only this leaf (discover on tools/<…>/<name>/ is empty — tests/ skipped).
  discovered = stdlib.mkTool.specs [ <devenv4monorepo/tools/profilers/memory/valgrind.nix> ];
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
