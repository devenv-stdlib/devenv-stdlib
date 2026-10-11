# when inherits javascript category policy (languages.javascript.enable or override).
# supported.javascript options are shared with TypeScript; the CI matrix flag
# here is JavaScript-only (typescript.ci-matrix is separate).
{ lib, ... }:
let
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  versionPolicy = import ../_shared/_version-policy.nix { inherit lib; };
  uniqueListOf = import ../_shared/unique-list.nix { inherit lib; };
in
{
  path = [
    "javascript"
    "supported"
  ];
  description = "supported.javascript options; CI matrix flag when JavaScript is available.";
  module = _: {
    options.supported.javascript = lib.mkOption {
      type = lib.types.submodule {
        options = {
          runtimes = lib.mkOption {
            type = uniqueListOf (lib.types.enum versions.jsRuntimes);
            default = [ ];
            description = "JS runtimes when javascript or typescript is on: nodejs, bun, deno. Repeated entries are kept once, in first-seen order.";
          };
          nodejs = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
          };
          bun = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
          };
          deno = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
            description = "Deno runtime version policy (languages.deno).";
          };
        };
      };
      default = { };
    };
  };
  project.stdlib.lang.javascript.ciMatrix = true;
}
