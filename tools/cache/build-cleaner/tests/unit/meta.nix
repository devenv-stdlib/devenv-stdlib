{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  discovered = stdlib.mkTool.specs [ <devenv4monorepo/tools/cache/build-cleaner.nix> ];
  byName = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
  bc = byName."build-cleaner".spec;
in
{
  testStdlibBuildCleanerIsGlobalBinary = {
    expr = {
      inherit (bc)
        category
        upgrade
        defaultEnable
        scopes
        isLocal
        isGlobal
        path
        ;
      inherit (bc.install) kind;
      packageIsFn = builtins.isFunction bc.install.package;
      denLoads = lib.any (d: d.spec.name == "build-cleaner") (lib.filter (d: d.spec.isGlobal) discovered);
      devenvLoads = lib.any (d: d.spec.name == "build-cleaner") (
        lib.filter (d: d.spec.isLocal) discovered
      );
    };
    expected = {
      category = "cache";
      upgrade = "self";
      defaultEnable = false;
      kind = "binary";
      packageIsFn = true;
      # Global HM leaf; local install is the thin preset project payload.
      scopes = [ "global" ];
      isLocal = false;
      isGlobal = true;
      path = [
        "cache"
        "build-cleaner"
      ];
      denLoads = true;
      devenvLoads = false;
    };
  };
}
