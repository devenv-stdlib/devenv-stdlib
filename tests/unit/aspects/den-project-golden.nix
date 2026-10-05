# Phase 4: Den/project goldens — aspect includes + pure helpers (python-on).
_:
let
  flake = builtins.getFlake (toString ../../..);
  golden = flake.denProjectGolden;
in
{
  testDenProjectGoldenOverallMatch = {
    expr = golden.match;
    expected = true;
  };

  testDenProjectGoldenIncludes = {
    expr = golden.python.includes;
    expected = golden.expectedIncludes;
  };

  testDenProjectGoldenHooksRuff = {
    expr = golden.python.hooks.ruff;
    expected = true;
  };

  testDenProjectGoldenSerenaHasPython = {
    expr = builtins.elem "python" golden.python.serena;
    expected = true;
  };

  testDenProjectGoldenVscodeHasMsPython = {
    expr = builtins.elem "ms-python.python" golden.python.vscode;
    expected = true;
  };

  testDenProjectGoldenDebtmap = {
    expr = golden.python.debtmap;
    expected = [ "python" ];
  };
}
