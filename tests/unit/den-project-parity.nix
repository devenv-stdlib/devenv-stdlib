# Phase 3 W3.2: aspect-backed python fixture ≡ legacy project.nix helpers.
{ lib, denProjectBridge, ... }:
let
  flake = builtins.getFlake (toString ../..);
  parity = flake.denProjectParity;
  bridge = denProjectBridge;
in
{
  testDenProjectParityOverallMatch = {
    expr = parity.match;
    expected = true;
  };

  testDenProjectParityBridgeMatch = {
    expr = bridge.pythonParityMatch;
    expected = true;
  };

  testDenProjectParityIncludes = {
    expr = parity.aspect.includes;
    expected = [
      "python-hooks"
      "python-ide-recs"
      "python-serena"
      "python-debtmap"
    ];
  };

  testDenProjectParityHooksRuff = {
    expr = parity.aspect.hooks.ruff;
    expected = true;
  };

  testDenProjectParityHooksMatchLegacy = {
    expr = parity.aspect.hooks == parity.legacy.hooks;
    expected = true;
  };

  testDenProjectParitySerenaMatchLegacy = {
    expr = parity.aspect.serena == parity.legacy.serena;
    expected = true;
  };

  testDenProjectParityVscodeMatchLegacy = {
    expr = parity.aspect.vscode == parity.legacy.vscode;
    expected = true;
  };

  testDenProjectParityDebtmapMatchLegacy = {
    expr = parity.aspect.debtmap;
    expected = [ "python" ];
  };

  testDenProjectParitySerenaHasPython = {
    expr = builtins.elem "python" parity.aspect.serena;
    expected = true;
  };

  testDenProjectParityVscodeHasMsPython = {
    expr = builtins.elem "ms-python.python" parity.aspect.vscode;
    expected = true;
  };
}
