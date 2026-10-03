{ lib, stdlib }:
let
  project = import ../../modules/lib/project.nix { inherit lib; };
  shared = import ./_js-shared.nix { inherit lib; };
  bundlers = project.typescriptBundlers;
in
stdlib.mkPreset {
  name = "typescript";
  description = "TypeScript hooks, shared TS IDE pack, Serena, debtmap, and CI matrix inputs.";
  when = cfg: (cfg.languages.typescript or { }).enable or false;
  # Hard condition: the old languages.typescript throwIf. strict = false warns
  # and leaves this preset inert instead of failing evaluation.
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
  project = {
    git-hooks.hooks = shared.gitHooks;
    stdlib.lang.typescript = shared.contrib // {
      debtmap = [ "typescript" ];
      ciMatrix = true;
    };
  };
}
