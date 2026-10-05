{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  # Owner suite: load only this leaf (discover on tools/<…>/<name>/ is empty — tests/ skipped).
  discovered = stdlib.mkTool.specs [ <devenv4monorepo/tools/ide/cursor.nix> ];
  byName = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
in
{
  testStdlibCursorUpgradeIsSelf = {
    expr = byName.cursor.spec.upgrade;
    expected = "self";
  };
}
