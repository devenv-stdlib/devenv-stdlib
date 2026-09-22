# Den Phase 3 — custom `project` class spike (go/no-go)

**Abort criterion 3 (plan):** *No viable route from a Den `project`/`devenv`
class into devenv’s module system (or flake-parts `devenv.shells`) without
forking devenv or rewriting CI/matrix generation — keep aspects as
documentation + HM-only Den.*

## Verdict: **GO** (viable route without forking devenv)

| Check | Result |
| --- | --- |
| `den.classes.project` registered | Yes (`den/classes/project.nix`) |
| Language aspects attach `project` class payloads | Yes (`den/aspects/languages.nix`) |
| `den.lib.aspects.resolve "project" den.aspects.python` yields module | Yes (flake export `denProjectClass`) |
| Resolved markers include hub includes + leaf concerns | Yes (hooks / ide-recs / serena / debtmap) |
| Devenv CLI / `devenv.yaml` / CI matrix rewritten? | **No** — bridge is resolve → import |
| flake-parts `devenv.shells` adopted? | **No** (explicitly avoided) |
| devenv fork required? | **No** |

## Route chosen

**NVF/terranix-style:** resolve the aspect’s `project` class into a plain
NixOS-module-like attrset and hand it to devenv via `imports` (spike proves
resolve + eval; full `modules/` import lands at cutover).

Not chosen: flake-parts `devenv.shells` primary path (would reshape
shell/CI/Copier and trip criterion 3).

## What still dual-writes

- Copier → `languages.*.enable` remains the enable gate.
- `modules/lib/project.nix` helpers still compute hooks/serena/vscode/debtmap.
- `modules/lib/den-project-bridge.nix` + flake `denProjectParity` assert
  aspect-backed fixture ≡ legacy helpers for python-on.
- HM dual path: `home-switch` vs `home-switch-den` until Phase 4.

## Risks accepted for Phase 4

- Bridge packaging across Den flake inputs vs devenv lock (shared `lib` OK;
  careful with `pkgs`).
- Cutover must import resolved modules under `modules/` without fighting
  Copier enable flags (`mkIf` / guards).

## Abort not fired

Criterion 3 does **not** fire: a viable non-fork route exists and is tested.
Phase 4 may proceed on composition cutover; do not treat this as permission to
adopt flake-parts shells as the primary devenv entry.
