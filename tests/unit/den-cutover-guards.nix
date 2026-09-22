# Phase 4: assert dual-run shim adapters are gone from the tree.
{ lib, ... }:
let
  root = toString ../..;
  shimGone = path: !(builtins.pathExists (root + "/" + path));
in
{
  testDenLanguageShimDeleted = {
    expr = shimGone "modules/lib/den-language-shim.nix";
    expected = true;
  };

  testDenProjectBridgeDeleted = {
    expr = shimGone "modules/lib/den-project-bridge.nix";
    expected = true;
  };

  # home.nix remains as a failing compat stub (not a dual HM root).
  testHomeNixIsCompatStub = {
    expr = builtins.pathExists (root + "/home.nix");
    expected = true;
  };
}
