{
  pkgs,
  lib,
  ...
}:
let
  nonNix = import ../non-nix/lib.nix { inherit lib; };
  resolved = nonNix.resolve pkgs;
  project = nonNix.filterScope "project" resolved;
  projectNix = nonNix.nixPackages project;
  miseToml = nonNix.toMiseToml project;
  projectImages = nonNix.dockerImages project;
in
{
  packages = [ pkgs.mise ] ++ projectNix;

  # Regenerated on devenv:files. Do not edit; update modules/non-nix/catalog.json.
  files."mise.toml".text = miseToml;

  tasks = {
    "mise:install" = {
      exec = ''
        set -euo pipefail
        mise install
        ${lib.concatMapStrings (img: ''
          if command -v docker >/dev/null 2>&1; then
            docker pull ${lib.escapeShellArg img} || true
          fi
        '') projectImages}
      '';
      after = [ "devenv:files" ];
    };
    "devenv:enterShell".after = [ "mise:install" ];
  };
}
