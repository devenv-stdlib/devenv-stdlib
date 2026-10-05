# Mock CI matrix preset: markers + sync script matching report.matrixInventory shape.
_: {
  path = [
    "ci"
    "github_actions"
    "language-matrix"
  ];
  description = "Mock language matrix preset for stdlib.report / loader tests.";
  categoryPolicy = false;
  when = _: true;
  project =
    {
      config,
      lib,
      ...
    }:
    let
      pythonOn = (config.stdlib.lang.python or { }).ciMatrix or false;
      empty = !pythonOn;
    in
    {
      # Shape mirrors modules/languages/versions-lib.nix matrixReport.
      stdlib.markers.ciMatrix = {
        inherit empty;
        runners = [
          "ubuntu-24.04"
          "ubuntu-26.04"
        ];
        languages = {
          python = {
            enabled = pythonOn;
            rows = lib.optional pythonOn {
              version = "3.12";
              os = "ubuntu-24.04";
            };
          };
          rust = {
            enabled = false;
            rows = [ ];
          };
          go = {
            enabled = false;
            rows = [ ];
          };
          javascript = {
            enabled = false;
            rows = [ ];
          };
        };
      };
      scripts.sync-language-versions-workflow.exec = ''
        echo "mock sync-language-versions-workflow"
      '';
      enterShell = ''
        sync-language-versions-workflow
      '';
    };
}
