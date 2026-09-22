# Dual-write shim LOC tracker (Phase 2–3 / abort criterion 2 precursor).
# Alert if Den dual-write shim tax exceeds ~600 LOC without cutover plan.
#
# Counted as Den composition + thin adapters (not legacy HM/devenv bodies,
# not tests, not CASCADES/CONTRIBUTING prose). Re-run after edits:
#
#   find den -name '*.nix' | xargs wc -l
#   wc -l modules/lib/den-language-shim.nix modules/lib/den-project-bridge.nix
#
# Snapshot (Phase 3):
#   den/**/*.nix .................... 424 LOC (cascades + aspects + homes + class)
#   modules/lib/den-language-shim.nix .. 62 LOC
#   modules/lib/den-project-bridge.nix . 69 LOC
#   Total dual-write Den shim ........ 555 LOC  (< 600 alert)
#
# Phase 2 snapshot was 419 LOC. Phase 3 adds home-cli + project class + bridge.
# Abort criterion 2 (Phase 4): shim stays >~600 AND reviewers still grep project.nix.
# Legacy modules remain full implementations (intentional dual-write until Phase 4).
