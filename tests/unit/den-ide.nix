# Phase 2 W2.4: project IDE / sync aspect includes + vscode helper parity.
{
  lib,
  project,
  denLanguage,
  ideCascade,
  ...
}:
let
  cascade = ideCascade;
  includesOf = name: cascade.${name}.includes or [ ];
  hasInclude = aspect: child: builtins.elem child (includesOf aspect);
  sort = xs: lib.sort (a: b: a < b) xs;
in
{
  testDenProjectIdesIncludesVscodeRecs = {
    expr = hasInclude "project-ides" "vscode-recs";
    expected = true;
  };

  testDenProjectIdesIncludesCursorSync = {
    expr = hasInclude "project-ides" "cursor-sync-extensions";
    expected = true;
  };

  testDenProjectIdesIncludeCount = {
    expr = builtins.length (includesOf "project-ides");
    expected = 2;
  };

  testDenProjectIdesShimMatchesCascade = {
    expr = sort denLanguage.projectIdeIncludes;
    expected = sort (includesOf "project-ides");
  };

  testDenIdeLeavesHaveNoNestedIncludes = {
    expr = {
      vscode = includesOf "vscode-recs";
      cursorSync = includesOf "cursor-sync-extensions";
    };
    expected = {
      vscode = [ ];
      cursorSync = [ ];
    };
  };

  # Recommendation data shape still comes from project helpers (quirk consumer).
  testDenVscodeAlwaysRecommendStable = {
    expr = project.vscodeAlwaysRecommend;
    expected = [
      "datakurre.devenv"
      "jnoortheen.nix-ide"
    ];
  };

  testDenVscodePythonPackIds = {
    expr = project.vscodeLanguageIds.python;
    expected = [
      "ms-python.python"
      "ms-python.vscode-pylance"
      "ms-python.debugpy"
      "charliermarsh.ruff"
    ];
  };

  testDenVscodeUnwantedWhenPythonOff = {
    expr = builtins.elem "ms-python.python" (project.vscodeUnwanted { });
    expected = true;
  };

  testDenProjectIdesOnPullsCascade = {
    expr =
      let
        hubs = [ "project-ides" ];
        reachable = lib.unique (lib.concatMap (name: [ name ] ++ (includesOf name)) hubs);
      in
      sort reachable;
    expected = sort [
      "project-ides"
      "vscode-recs"
      "cursor-sync-extensions"
    ];
  };
}
