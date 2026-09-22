# Phase 2 W2.2: Den python aspect includes DAG + shim parity with project helpers.
{
  lib,
  project,
  denLanguage,
  languageCascade,
  ...
}:
let
  cascade = languageCascade;
  includesOf = name: cascade.${name}.includes or [ ];
  hasInclude = aspect: child: builtins.elem child (includesOf aspect);
  expected = denLanguage.expectedChildren.python;
in
{
  testDenPythonIncludesHooks = {
    expr = hasInclude "python" "python-hooks";
    expected = true;
  };

  testDenPythonIncludesIdeRecs = {
    expr = hasInclude "python" "python-ide-recs";
    expected = true;
  };

  testDenPythonIncludesSerena = {
    expr = hasInclude "python" "python-serena";
    expected = true;
  };

  testDenPythonIncludesDebtmap = {
    expr = hasInclude "python" "python-debtmap";
    expected = true;
  };

  testDenPythonIncludeCount = {
    expr = builtins.length (includesOf "python");
    expected = 4;
  };

  testDenPythonIncludesMatchExpected = {
    expr = lib.sort (a: b: a < b) (includesOf "python");
    expected = lib.sort (a: b: a < b) expected;
  };

  testDenPythonLeavesHaveNoNestedIncludes = {
    expr = map includesOf expected;
    expected = [
      [ ]
      [ ]
      [ ]
      [ ]
    ];
  };

  # Shim surfaces the same DAG project.denLanguage reads.
  testDenPythonShimMatchesCascade = {
    expr = denLanguage.includesOf "python";
    expected = includesOf "python";
  };

  # Enable path still drives helpers (Copier flags); cascade documents fan-out.
  testDenPythonEnableStillDrivesHooks = {
    expr = (project.languageHooks { languages.python.enable = true; }).ruff;
    expected = true;
  };

  testDenPythonEnableStillDrivesSerena = {
    expr = builtins.elem "python" (project.serenaLanguageServers { python.enable = true; });
    expected = true;
  };

  testDenPythonEnableStillDrivesVscode = {
    expr = builtins.elem "ms-python.python" (project.vscodeRecommendations { python.enable = true; });
    expected = true;
  };

  testDenPythonEnableStillDrivesDebtmap = {
    expr = project.debtmapLanguages { python.enable = true; };
    expected = [ "python" ];
  };

  testDenPythonOffDropsCascade = {
    expr =
      let
        developerIncludes = [ ];
        reachable = lib.concatMap (name: [ name ] ++ (includesOf name)) developerIncludes;
      in
      reachable;
    expected = [ ];
  };

  testDenPythonOnPullsCascade = {
    expr =
      let
        hubs = [ "python" ];
        reachable = lib.unique (lib.concatMap (name: [ name ] ++ (includesOf name)) hubs);
      in
      lib.sort (a: b: a < b) reachable;
    expected = lib.sort (a: b: a < b) ([ "python" ] ++ expected);
  };
}
