# Phase 0 baseline smoke record

**Date:** 2026-09-22  
**Branch:** `cursor/den-rewrite-phase-0-inventory-06ff`  
**Purpose:** Integration baseline before Den (Phase 1). Per phase test plans: record smoke + confirm `home-switch` → `home.nix`.

## home-switch (pre-Den)

Confirmed in `devenv.nix`:

```text
home-manager switch -b backup -f "$DEVENV_ROOT/home.nix"
```

Automated: `tests/den/phase-0-inventory.bats` (`home-switch still targets home.nix`).

## Commands run (this PR)

| Command | Result |
| --- | --- |
| `bats tests/den/phase-0-inventory.bats` | **8/8 ok** |
| `nix run --impure github:nix-community/nix-unit -- tests/unit/default.nix` | **125/125 successful** |
| `bats tests/home/cursor-llm.bats tests/home/terminal-lib.bats` | **13/13 ok** (with inventory: 21/21) |

Full recursive `bats -r tests` / `test-devenv` not required to merge Phase 0 (docs + inventory gates only); carry forward for Phase 1+.

## Notes

- No Den flake/npins input in this phase.
- CI ignored per Project preference; local suite membership is the gate.
- `scripts.home-switch` still points at `home.nix` (pre-Den).
