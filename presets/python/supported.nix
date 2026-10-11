# Thin language-scoped options + CI matrix flag.
{ lib, ... }:
let
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  versionPolicy = import ../_shared/_version-policy.nix { inherit lib; };
  uniqueListOf = import ../_shared/unique-list.nix { inherit lib; };
in
{
  path = [
    "python"
    "supported"
  ];
  description = "supported.python options and CI matrix flag when Python is on.";
  module = _: {
    options.supported.python = lib.mkOption {
      type = lib.types.submodule {
        options = versionPolicy {
          implementations = lib.mkOption {
            type = uniqueListOf (lib.types.enum versions.pythonImpls);
            default = [ "cpython" ];
            description = "Python 3 implementations to test. cpython and/or pypy. Repeated entries are kept once, in first-seen order.";
          };
        };
      };
      default = { };
    };
  };
  project.stdlib.lang.python.ciMatrix = true;
}
