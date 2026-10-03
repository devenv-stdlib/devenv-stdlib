# Adding a Den aspect (Phase 4 contributor guide)

**Den owns composition.** Aspects + `includes` are the cascade source of truth.
`home-switch` is Den-only (`den.homes` → flake `#developer`). Pure helpers in
`modules/lib/project.nix` still map Copier `languages.*.enable` → hooks / serena
/ vscode / debtmap lists.

## Prefer: new feature as an aspect

1. **Pick the cascade file** (`modules/den/_cascades/cursor-cascade.nix`, `terminal-cascade.nix`,
   `language-cascade.nix`, `ide-cascade.nix`) and add the hub/leaf `includes`
   edge as a string name.
2. **Add `modules/aspects/<name>.nix`** (or extend `languages.nix` / `project-ides.nix`)
   mapping those names onto `den.aspects.*` with:
   - `includes = map (n: den.aspects.${n}) cascade.<name>.includes;`
   - `homeManager = { … }` for user-profile features, **or**
   - `project = { … }` for devenv/toolchain features (custom class).
3. **Drop the file under `modules/aspects/` or `modules/den/`** — flake
   `import-tree` discovers it (and into `den.aspects.developer.includes`
   when it belongs on every developer home).
4. **Tests:** extend the matching `tests/unit/den-*.nix` includes asserts; keep
   `nix-unit tests/unit/default.nix` and `bats -r tests` green.
5. **Do not** add zen / flake-aspects / dendrix. Sister libs only if a phase
   gate already pulled them.

### Home vs project vs OS classes

| Lifetime | Class key | Lands in |
| --- | --- | --- |
| User profile (terminal, Cursor, CLIs) | `homeManager` | `den.homes` → `home-switch` |
| Project toolchain (hooks, serena, IDE recs) | `project` | resolve → devenv modules |
| Host OS (NixOS / Darwin stubs) | `nixos` / `darwin` | `den.hosts` (Phase 5; stubs until real hosts) |

Portable features: one shared payload on `nixos` + `darwin` (see
`modules/aspects/shell-tools.nix`). Ubuntu-only GNOME quake stays HM-only —
do not add OS class keys (`modules/den/MULTI-OS.md`).

GUI terminal / Cursor stay **out of** devenv PATH — same architecture rule,
now visible as two class keys on one aspect when needed.

## Avoid

- Grepping `project.nix` `langOn` to learn fan-out — read aspect `includes` /
  `modules/den/CASCADES.md` first.
- Reviving a parallel legacy HM root (`home-manager -f home.nix`).
- Putting Copier questionnaire logic into Den policies.
- Forking devenv or migrating to flake-parts `devenv.shells` for the project
  class (abort criterion 3). Use `den.lib.aspects.resolve "project" aspect`
  and import the module under `modules/` instead.

## HM modules

Small HM CLIs land as `home/<tool>.nix` imported from
`modules/aspects/home-cli.nix` (or a dedicated aspect). New cascades should still
get an aspect name + includes edge so the DAG stays readable.

`home.nix` is a **compat stub** that fails if evaluated with `-f`; do not use it.

## Entry point

| Script | Entry |
| --- | --- |
| `home-switch` | flake `.#developer --impure` (Den) |

Goldens: `nix eval .#denHmGolden` / `.#denProjectGolden` / `.#denOsClasses`.
