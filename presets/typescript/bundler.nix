# Thin gate: TypeScript availability requires a bundler choice.
# when inherits typescript category policy; bundler assertion stays leaf-specific.
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
  description = "Requires typescript.bundler when TypeScript is available.";
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
