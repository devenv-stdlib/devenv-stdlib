# Thin gate: TypeScript enable requires a bundler choice.
{ lib, ... }:
let
  project = import ../../modules/lib/project.nix { inherit lib; };
  bundlers = project.typescriptBundlers;
in
{
  path = [
    "typescript"
    "bundler"
  ];
  description = "Requires typescript.bundler when languages.typescript.enable.";
  when = cfg: (cfg.languages.typescript or { }).enable or false;
  requires = [
    {
      assertion = cfg: (cfg.typescript.bundler or null) != null;
      message = ''
        languages.typescript.enable requires typescript.bundler to be one of:
          ${lib.concatStringsSep " | " bundlers}
        Use rspack for legacy webpack applications.
      '';
    }
  ];
  project = { };
}
