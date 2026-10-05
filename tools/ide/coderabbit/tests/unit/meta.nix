{ lib, ... }:
let
  stdlib = import <devenv4monorepo/stdlib> { inherit lib; };
  # Owner suite: load only this leaf (discover on tools/<…>/<name>/ is empty — tests/ skipped).
  discovered = stdlib.mkTool.specs [ <devenv4monorepo/tools/ide/coderabbit.nix> ];
  byName = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
  cr = byName.coderabbit.spec;
in
{
  testStdlibCoderabbitIsOpenVsxExtension = {
    expr = {
      inherit (cr)
        category
        upgrade
        defaultEnable
        path
        ;
      inherit (cr.install)
        kind
        publisher
        extension
        registry
        ;
    };
    expected = {
      category = "ide";
      upgrade = "catalog";
      defaultEnable = true;
      kind = "vscode-extension";
      publisher = "coderabbit";
      extension = "coderabbit-vscode";
      registry = "open-vsx";
      path = [
        "ide"
        "coderabbit"
      ];
    };
  };
}
