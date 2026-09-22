# Language aspect DAG (Phase 2 W2.2–W2.3).
# Project/devenv class lands in Phase 3; these aspects are the includes source of
# truth. Devenv modules still gate on languages.*.enable and import the cascade
# via modules/lib/den-language-shim.nix (thin dual-write adapter).
{ den, ... }:
let
  cascade = import ../language-cascade.nix;
  mkLeaf = name: {
    includes = map (n: den.aspects.${n}) (cascade.${name}.includes or [ ]);
  };
  mkHub = name: {
    includes = map (n: den.aspects.${n}) cascade.${name}.includes;
  };
in
{
  den.aspects = {
    python = mkHub "python";
    python-hooks = mkLeaf "python-hooks";
    python-ide-recs = mkLeaf "python-ide-recs";
    python-serena = mkLeaf "python-serena";
    python-debtmap = mkLeaf "python-debtmap";

    rust = mkHub "rust";
    rust-hooks = mkLeaf "rust-hooks";
    rust-ide-recs = mkLeaf "rust-ide-recs";
    rust-serena = mkLeaf "rust-serena";
    rust-debtmap = mkLeaf "rust-debtmap";

    go = mkHub "go";
    go-hooks = mkLeaf "go-hooks";
    go-ide-recs = mkLeaf "go-ide-recs";
    go-serena = mkLeaf "go-serena";
    go-debtmap = mkLeaf "go-debtmap";

    javascript = mkHub "javascript";
    javascript-hooks = mkLeaf "javascript-hooks";
    javascript-ide-recs = mkLeaf "javascript-ide-recs";
    javascript-serena = mkLeaf "javascript-serena";
    javascript-debtmap = mkLeaf "javascript-debtmap";

    typescript = mkHub "typescript";
    typescript-hooks = mkLeaf "typescript-hooks";
    typescript-ide-recs = mkLeaf "typescript-ide-recs";
    typescript-serena = mkLeaf "typescript-serena";
    typescript-debtmap = mkLeaf "typescript-debtmap";
  };
}
