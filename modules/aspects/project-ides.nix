# Project IDE / sync aspects (Phase 2 W2.4).
# vscode recommendations + cursor-sync-extensions on enterShell.
# Writers live in presets/languages/*.nix (stdlib.devenv.load); this DAG is
# the composition surface.
{ den, ... }:
let
  cascade = import ../den/_cascades/ide-cascade.nix;
  mkLeaf = name: {
    includes = map (n: den.aspects.${n}) (cascade.${name}.includes or [ ]);
  };
in
{
  den.aspects = {
    project-ides = {
      includes = map (n: den.aspects.${n}) cascade.project-ides.includes;
    };
    vscode-recs = mkLeaf "vscode-recs";
    cursor-sync-extensions = mkLeaf "cursor-sync-extensions";
  };
}
