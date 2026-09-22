# Dual-write shim LOC tracker (Phase 2 acceptance / abort criterion 2 precursor).
# Alert if Phase 2 Den dual-write shim tax exceeds ~600 LOC without cutover plan.
#
# Counted as Phase 2 Den composition + thin adapters (not legacy HM/devenv bodies,
# not tests, not CASCADES.md prose). Re-run after edits:
#
#   find den -name '*.nix' | xargs wc -l
#   wc -l modules/lib/den-language-shim.nix
#
# Snapshot (this PR):
#   den/**/*.nix ............... ~350 LOC (cascades + aspects + homes)
#   modules/lib/den-language-shim.nix ~55 LOC
#   Total dual-write Den shim ... ~405 LOC  (< 600 alert)
#
# Legacy modules remain full implementations (intentional dual-write until Phase 4).
