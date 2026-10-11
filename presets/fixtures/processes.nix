# Fixture exemplar: a devenv feature (non-empty processes) activates a preset.
# Loaded by tests/unit/presets-devenv.nix, not by modules/devenv.nix.
_: {
  path = [
    "fixtures"
    "processes"
  ];
  description = "Exemplar: processes != {} activates a preset.";
  when = cfg: (cfg.processes or { }) != { };
  project = {
    stdlib.markers.processes = true;
  };
}
