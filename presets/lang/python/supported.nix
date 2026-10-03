# Thin language-scoped options + CI matrix flag (not a tool megapreset).
{ lib, ... }:
let
  versions = import ../../../modules/languages/versions-lib.nix { inherit lib; };
  versionPolicy = import ../_shared/_version-policy.nix { inherit lib; };
in
{
  name = "python-supported";
  description = "supported.python options and CI matrix flag when Python is on.";
  when = cfg: (cfg.languages.python or { }).enable or false;
  module = _: {
    options.supported.python = lib.mkOption {
      type = lib.types.submodule {
        options = versionPolicy {
          implementations = lib.mkOption {
            type = lib.types.listOf (lib.types.enum versions.pythonImpls);
            default = [ "cpython" ];
            description = "Python 3 implementations to test. cpython and/or pypy.";
          };
        };
      };
      default = { };
    };
  };
  project.stdlib.lang.python.ciMatrix = true;
}
