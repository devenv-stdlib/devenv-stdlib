{ lib, ... }:
let
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  versionPolicy = import ./_version-policy.nix { inherit lib; };
  shared = import ./_js-shared.nix { inherit lib; };
in
{
  name = "javascript";
  description = "JavaScript hooks, shared TS IDE pack, Serena, debtmap, and CI matrix inputs.";
  when = cfg: (cfg.languages.javascript or { }).enable or false;
  # supported.javascript is shared with TypeScript (one matrix for both).
  module = _: {
    options.supported.javascript = lib.mkOption {
      type = lib.types.submodule {
        options = {
          runtimes = lib.mkOption {
            type = lib.types.listOf (lib.types.enum versions.jsRuntimes);
            default = [ ];
            description = "JS runtimes when javascript or typescript is on: nodejs, bun, deno.";
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
  project = {
    git-hooks.hooks = shared.gitHooks;
    stdlib.lang.javascript = shared.contrib // {
      debtmap = [ "javascript" ];
      ciMatrix = true;
    };
  };
}
