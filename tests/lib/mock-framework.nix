# Roots and helpers for the mock tools/presets tree used by the main suite.
# Real tools/ and presets/ stay covered by per-owner suites.
{ lib }:
let
  root = ../fixtures/mock-framework;
  presetsRoot = root + "/presets";
  toolsRoot = root + "/tools";
in
{
  inherit lib root;
  tools = toolsRoot;
  presets = presetsRoot;

  # Explicit preset category roots (defaultRoots only lists devenv languages +
  # services/ci/fixtures — mock terminal/ide/demo need to be named).
  presetRoots = [
    (presetsRoot + "/python")
    (presetsRoot + "/terminal")
    (presetsRoot + "/ide")
    (presetsRoot + "/demo")
    (presetsRoot + "/fixtures")
    (presetsRoot + "/ci")
  ];

  loadArgs = {
    presets = [
      (presetsRoot + "/python")
      (presetsRoot + "/terminal")
      (presetsRoot + "/ide")
      (presetsRoot + "/demo")
      (presetsRoot + "/fixtures")
      (presetsRoot + "/ci")
    ];
    tools = [ toolsRoot ];
  };
}
