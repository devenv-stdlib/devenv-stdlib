{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  discovered = stdlib.mkTool.specs (stdlib.discover [ <devenv4monorepo/tools> ]);
  byName = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
in
{
  testStdlibCursorUpgradeIsSelf = {
    expr = byName.cursor.spec.upgrade;
    expected = "self";
  };
}
