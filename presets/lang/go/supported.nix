{ lib, ... }:
let
  versionPolicy = import ../_shared/_version-policy.nix { inherit lib; };
in
{
  name = "go-supported";
  description = "supported.go options and CI matrix flag when Go is on.";
  when = cfg: (cfg.languages.go or { }).enable or false;
  module = _: {
    options.supported.go = lib.mkOption {
      type = lib.types.submodule { options = versionPolicy { }; };
      default = { };
    };
  };
  project.stdlib.lang.go.ciMatrix = true;
}
