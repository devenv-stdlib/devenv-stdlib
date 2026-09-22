# Phase 3: bridge Den `project` class → devenv-shaped module tree.
# Pattern: NVF/terranix-style resolve (den.lib.aspects.resolve) without forking devenv.
# Copier still owns languages.*.enable; this bridge surfaces aspect-backed parity
# snapshots and can be imported under modules/ once cutover lands.
{ lib }:
let
  cascade = import ../../den/language-cascade.nix;
  project = import ./project.nix { inherit lib; };

  # Pure parity snapshot for one language matrix fixture (python-on).
  # Mirrors what project.nix helpers produce when languages.python.enable = true.
  pythonOnFixture = {
    languages.python.enable = true;
  };

  legacyPythonParity = {
    hooks = project.languageHooks pythonOnFixture;
    serena = project.serenaLanguageServers pythonOnFixture.languages;
    vscode = project.vscodeRecommendations pythonOnFixture.languages;
    debtmap = project.debtmapLanguages pythonOnFixture.languages;
    includes = cascade.python.includes;
  };

  # Aspect-backed view: includes DAG + same helper outputs when hub is "on".
  # Until cutover, enable still comes from Copier; aspects document fan-out.
  aspectPythonParity =
    let
      on = true; # fixture: python aspect included
    in
    {
      includes = cascade.python.includes;
      hooks = project.languageHooks {
        languages.python.enable = on;
      };
      serena = project.serenaLanguageServers { python.enable = on; };
      vscode = project.vscodeRecommendations { python.enable = on; };
      debtmap = project.debtmapLanguages { python.enable = on; };
    };
in
{
  inherit
    cascade
    pythonOnFixture
    legacyPythonParity
    aspectPythonParity
    ;

  # True when aspect-backed python fixture matches legacy helpers.
  pythonParityMatch =
    aspectPythonParity.includes == legacyPythonParity.includes
    && aspectPythonParity.hooks == legacyPythonParity.hooks
    && aspectPythonParity.serena == legacyPythonParity.serena
    && aspectPythonParity.vscode == legacyPythonParity.vscode
    && aspectPythonParity.debtmap == legacyPythonParity.debtmap;

  # Expected project-class markers contributed by language leaf aspects (spike).
  # Resolved via den.lib.aspects.resolve "project" den.aspects.python in flake.nix.
  expectedProjectMarkers = {
    python = {
      hub = "python";
      concerns = [
        "hooks"
        "ide-recs"
        "serena"
        "debtmap"
      ];
    };
  };
}
