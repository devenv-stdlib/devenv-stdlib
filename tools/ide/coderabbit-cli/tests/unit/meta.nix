{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  discovered = stdlib.mkTool.specs (stdlib.discover [ <devenv4monorepo/tools> ]);
  byName = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
  cr = byName."coderabbit-cli".spec;
in
{
  testStdlibCoderabbitCliIsBinary = {
    expr = {
      inherit (cr)
        category
        upgrade
        defaultEnable
        path
        ;
      inherit (cr.install) kind;
    };
    expected = {
      category = "ide";
      upgrade = "self";
      defaultEnable = true;
      kind = "binary";
      path = [
        "ide"
        "coderabbit-cli"
      ];
    };
  };
}
