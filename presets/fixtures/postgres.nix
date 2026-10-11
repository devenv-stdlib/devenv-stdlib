# Fixture exemplar: services.postgres.enable pulls usql plus an IDE id.
# The Home Manager usql package override stays in home/usql.nix.
# Loaded by tests/unit/presets-devenv.nix, not by modules/devenv.nix.
# usql is not yet a mkTool leaf; synthesize a tools.data.usql ref for includes.
{ lib, ... }:
let
  toolLib = import ../../stdlib/tool.nix { inherit lib; };
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
    "postgres"
  ];
  description = "Exemplar: postgres enables the usql tool and a SQL editor extension.";
  when = cfg: ((cfg.services or { }).postgres or { }).enable or false;
  # Declared for Den tool include when mkPreset lowers `tools`.
  tools = [ tools.data.usql ];
  project =
    { pkgs, ... }:
    {
      packages = [ pkgs.usql ];
      stdlib.markers.postgresIdeExtension = "mtxr.sqltools";
      stdlib.lang.postgres = {
        vscodeIds = [ "mtxr.sqltools" ];
      };
    };
}
