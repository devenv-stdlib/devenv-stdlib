# Language aspect DAG (Phase 2 W2.2–W2.3) + Phase 3 project class payloads.
# Includes remain the cascade source of truth. Project class modules are resolved
# via den.lib.aspects.resolve → devenv-shaped eval (see modules/lib/den-project-bridge.nix).
# Copier still owns languages.*.enable until Phase 4 cutover.
{ den, lib, ... }:
let
  cascade = import ../language-cascade.nix;

  # Leaf aspect: includes + project-class marker for the concern it documents.
  mkLeaf = name: concern: {
    includes = map (n: den.aspects.${n}) (cascade.${name}.includes or [ ]);
    project = {
      # Freeform-friendly markers for resolve → parity / devenv bridge spike.
      denProject.markers.${name} = {
        inherit concern;
        hub = lib.head (lib.splitString "-" name);
      };
    };
  };

  mkHub = name: {
    includes = map (n: den.aspects.${n}) cascade.${name}.includes;
    project = {
      denProject.hubs.${name} = {
        includes = cascade.${name}.includes;
      };
    };
  };
in
{
  den.aspects = {
    python = mkHub "python";
    python-hooks = mkLeaf "python-hooks" "hooks";
    python-ide-recs = mkLeaf "python-ide-recs" "ide-recs";
    python-serena = mkLeaf "python-serena" "serena";
    python-debtmap = mkLeaf "python-debtmap" "debtmap";

    rust = mkHub "rust";
    rust-hooks = mkLeaf "rust-hooks" "hooks";
    rust-ide-recs = mkLeaf "rust-ide-recs" "ide-recs";
    rust-serena = mkLeaf "rust-serena" "serena";
    rust-debtmap = mkLeaf "rust-debtmap" "debtmap";

    go = mkHub "go";
    go-hooks = mkLeaf "go-hooks" "hooks";
    go-ide-recs = mkLeaf "go-ide-recs" "ide-recs";
    go-serena = mkLeaf "go-serena" "serena";
    go-debtmap = mkLeaf "go-debtmap" "debtmap";

    javascript = mkHub "javascript";
    javascript-hooks = mkLeaf "javascript-hooks" "hooks";
    javascript-ide-recs = mkLeaf "javascript-ide-recs" "ide-recs";
    javascript-serena = mkLeaf "javascript-serena" "serena";
    javascript-debtmap = mkLeaf "javascript-debtmap" "debtmap";

    typescript = mkHub "typescript";
    typescript-hooks = mkLeaf "typescript-hooks" "hooks";
    typescript-ide-recs = mkLeaf "typescript-ide-recs" "ide-recs";
    typescript-serena = mkLeaf "typescript-serena" "serena";
    typescript-debtmap = mkLeaf "typescript-debtmap" "debtmap";
  };
}
