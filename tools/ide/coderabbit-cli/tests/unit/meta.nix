{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  # Owner suite: load only this leaf (discover on tools/<…>/<name>/ is empty — tests/ skipped).
  discovered = stdlib.mkTool.specs [ <devenv4monorepo/tools/ide/coderabbit-cli.nix> ];
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
      packageIsFn = builtins.isFunction cr.install.package;
    };
    expected = {
      category = "ide";
      upgrade = "self";
      defaultEnable = true;
      kind = "binary";
      packageIsFn = true;
      path = [
        "ide"
        "coderabbit-cli"
      ];
    };
  };
}
