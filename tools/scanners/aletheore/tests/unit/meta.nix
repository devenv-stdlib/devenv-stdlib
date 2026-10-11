{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  discovered = stdlib.mkTool.specs [ <devenv4monorepo/tools/scanners/aletheore.nix> ];
  byName = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
  aletheore = byName.aletheore.spec;
in
{
  testStdlibAletheoreIsLocalCatalog = {
    expr = {
      inherit (aletheore)
        category
        upgrade
        defaultEnable
        scopes
        isLocal
        isGlobal
        path
        ;
      inherit (aletheore.install) kind name;
    };
    expected = {
      category = "scanners";
      upgrade = "catalog";
      defaultEnable = false;
      kind = "catalog";
      name = "aletheore";
      scopes = [ "local" ];
      isLocal = true;
      isGlobal = false;
      path = [
        "scanners"
        "aletheore"
      ];
    };
  };
}
