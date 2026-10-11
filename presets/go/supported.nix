# when inherits go category policy (languages.go.enable or override).
{ lib, ... }:
let
  versionPolicy = import ../_shared/_version-policy.nix { inherit lib; };
in
{
  path = [
    "go"
    "supported"
  ];
  description = "supported.go options and CI matrix flag when Go is available.";
  module = _: {
    options.supported.go = lib.mkOption {
      type = lib.types.submodule { options = versionPolicy { }; };
      default = { };
    };
  };
  project.stdlib.lang.go.ciMatrix = true;
}
