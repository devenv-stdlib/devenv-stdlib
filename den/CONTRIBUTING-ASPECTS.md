# Adding a Den aspect (Phase 3 contributor guide)

This template is mid dual-run: **Den owns cascade composition**; legacy
`home.nix` / `project.nix` helpers still evaluate until Phase 4 cutover.

## Prefer: new feature as an aspect

1. **Pick the cascade file** (`den/cursor-cascade.nix`, `terminal-cascade.nix`,
   `language-cascade.nix`, `ide-cascade.nix`) and add the hub/leaf `includes`
   edge as a string name.
2. **Add `den/aspects/<name>.nix`** (or extend `languages.nix` / `project-ides.nix`)
   mapping those names onto `den.aspects.*` with:
   - `includes = map (n: den.aspects.${n}) cascade.<name>.includes;`
   - `homeManager = { … }` for user-profile features, **or**
   - `project = { … }` for devenv/toolchain features (custom class; Phase 3).
3. **Wire the module** into `flake.nix` `denModules` (and into
   `den.aspects.developer.includes` when it belongs on every developer home).
4. **Tests:** extend the matching `tests/unit/den-*.nix` includes asserts; keep
   `nix-unit tests/unit/default.nix` and `bats -r tests` green.
5. **Do not** add zen / flake-aspects / dendrix. Sister libs only if a phase
   gate already pulled them.

### Home vs project class

| Lifetime | Class key | Lands in |
| --- | --- | --- |
| User profile (terminal, Cursor, CLIs) | `homeManager` | `den.homes` → `home-switch-den` |
| Project toolchain (hooks, serena, IDE recs) | `project` | resolve → devenv modules (bridge) |

GUI terminal / Cursor stay **out of** devenv PATH — same architecture rule,
now visible as two class keys on one aspect when needed.

## Avoid (during dual-run)

- Grepping `project.nix` `langOn` to learn fan-out — read aspect `includes` /
  `den/CASCADES.md` first.
- Deleting `home.nix` or collapsing `project.nix` helpers — Phase 4 only.
- Putting Copier questionnaire logic into Den policies.
- Forking devenv or migrating to flake-parts `devenv.shells` for the project
  class (abort criterion 3). Use `den.lib.aspects.resolve "project" aspect`
  and import the module under `modules/` instead.

## Legacy module path (still valid)

Small HM CLIs can still land as `home/<tool>.nix` imported from
`den/aspects/home-cli.nix` (parity shim) **and** `home.nix` until cutover.
New cascades should still get an aspect name + includes edge so the DAG stays
readable.

## Dual paths (Phase 3)

| Script | Entry |
| --- | --- |
| `home-switch` | `home-manager -f home.nix` (legacy) |
| `home-switch-den` | flake `.#developer` (Den) |

Parity fingerprints: `nix eval .#denHmParity` / `.#denProjectParity`.
