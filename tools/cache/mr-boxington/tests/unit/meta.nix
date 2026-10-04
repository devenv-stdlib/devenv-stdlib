{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  # Owner suite: load only this leaf (discover on tools/<…>/<name>/ is empty — tests/ skipped).
  discovered = stdlib.mkTool.specs [ <devenv4monorepo/tools/cache/mr-boxington.nix> ];
  byName = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
  mbx = byName."mr-boxington".spec;
in
{
  testStdlibMrBoxingtonIsGlobalBinary = {
    expr = {
      inherit (mbx)
        category
        upgrade
        defaultEnable
        scopes
        isLocal
        isGlobal
        path
        ;
      inherit (mbx.install) kind;
      packageIsFn = builtins.isFunction mbx.install.package;
      denLoads = lib.any (d: d.spec.name == "mr-boxington") (lib.filter (d: d.spec.isGlobal) discovered);
      devenvLoads = lib.any (d: d.spec.name == "mr-boxington") (
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
        "mr-boxington"
      ];
      denLoads = true;
      devenvLoads = false;
    };
  };
}
