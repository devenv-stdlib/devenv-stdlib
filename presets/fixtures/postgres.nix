# Fixture exemplar: services.postgres.enable pulls usql plus an IDE id.
# The Home Manager usql package override stays in home/usql.nix.
# Loaded by tests/unit/presets-devenv.nix, not by modules/devenv.nix.
_: {
  path = [
    "fixtures"
    "postgres"
  ];
  description = "Exemplar: postgres enables the usql tool and a SQL editor extension.";
  when = cfg: ((cfg.services or { }).postgres or { }).enable or false;
  # Declared for Den tool include when mkPreset lowers `tools`.
  tools = [ "usql" ];
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
