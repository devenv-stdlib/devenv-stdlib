# Phase 3 W3.3: custom project class registration + resolve → markers.
{ lib, ... }:
let
  flake = builtins.getFlake (toString ../..);
  klass = flake.denProjectClass;
in
{
  testDenProjectClassRegistered = {
    expr = klass.registered;
    expected = true;
  };

  testDenProjectClassPythonHubIncludes = {
    expr = klass.pythonHub.includes or [ ];
    expected = [
      "python-hooks"
      "python-ide-recs"
      "python-serena"
      "python-debtmap"
    ];
  };

  testDenProjectClassLeafConcerns = {
    expr = klass.pythonLeafConcerns;
    expected = [
      "debtmap"
      "hooks"
      "ide-recs"
      "serena"
    ];
  };

  testDenProjectClassConcernCount = {
    expr = builtins.length klass.pythonLeafConcerns;
    expected = 4;
  };
}
