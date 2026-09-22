# Dual-write shim LOC tracker — Phase 4 cutover (cleared)

Abort criterion 2: shim/`imports` dual-write stays >~600 LOC *and* reviewers
still grep `project.nix` instead of `includes` DAGs.

## Post-cutover snapshot

```
# Counted as Den composition only (adapters deleted):
#   find den -name '*.nix' | xargs wc -l
#
# Dual-write adapters REMOVED:
#   modules/lib/den-language-shim.nix  (deleted)
#   modules/lib/den-project-bridge.nix (deleted)
#   legacy home-switch -f home.nix     (deleted; stub only)
#
# den/**/*.nix .................... 440 LOC (composition, not dual-write)
# Dual-write shim tax ............. 0 LOC  (cleared)
```

Cascade readability: `den/*-cascade.nix` + `den/aspects/*` `includes`.
`modules/lib/project.nix` keeps **pure** enable→list helpers for debtmap /
serena / vscode / hooks — not a fan-out god-table.

**Verdict:** Criterion 2 does **not** fire after cutover (shim tax cleared).
