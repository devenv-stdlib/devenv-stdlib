# Discovery wiring for per-tool / per-preset suites and tests/ skips.
{ lib, ... }:
let
  discoverSuites = import ../../lib/discover-suites.nix { inherit lib; };
  stdlib = import ../../../stdlib { inherit lib; };
  fixtureRoot = ../../fixtures/suite-discover;

  classify =
    path:
    let
      s = toString path;
    in
    if lib.hasSuffix "tools/demo/tests/unit/default.nix" s then
      "tools/demo/unit"
    else if lib.hasSuffix "presets/x/tests/unit/default.nix" s then
      "presets/x/unit"
    else if lib.hasSuffix "presets/x/tests/integration/default.nix" s then
      "presets/x/integration"
    else
      s;
in
{
  testDiscoverUnitSuitesFindsOwnerDefaults = {
    expr = lib.sort (a: b: a < b) (
      map classify (
        discoverSuites.discoverUnitSuites [
          (fixtureRoot + "/tools")
          (fixtureRoot + "/presets")
        ]
      )
    );
    expected = [
      "presets/x/unit"
      "tools/demo/unit"
    ];
  };

  testDiscoverIntegrationSuitesFindsOwnerDefaults = {
    expr = map classify (
      discoverSuites.discoverIntegrationSuites [
        (fixtureRoot + "/tools")
        (fixtureRoot + "/presets")
      ]
    );
    expected = [ "presets/x/integration" ];
  };

  testStdlibDiscoverSkipsTestsDirectories = {
    expr = map baseNameOf (stdlib.discover [ ../../fixtures/stdlib-discover ]);
    expected = [ "leaf.nix" ];
  };
}
