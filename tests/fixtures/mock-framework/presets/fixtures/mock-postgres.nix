# Fixture exemplar: services.postgres.enable → packages + marker.
{ lib, ... }:
let
  toolLib = (import ../../lib.nix { inherit lib; }).tool;
  tools = toolLib.refsFromPaths [
    [
      "data"
      "usql"
    ]
  ];
in
{
  path = [
    "fixtures"
    "mock-postgres"
  ];
  description = "Mock postgres exemplar preset.";
  categoryPolicy = false;
  when = cfg: ((cfg.services or { }).postgres or { }).enable or false;
  tools = [ tools.data.usql ];
  project =
    { pkgs, ... }:
    {
      packages = [ pkgs.usql ];
      stdlib.markers.postgresIdeExtension = "mtxr.sqltools";
    };
}
