# IDEs module layout and VS Code → Cursor inheritance

## Goal

Move editor/IDE wiring out of `modules/languages/` into a first-class `ides` category, regroup Home Manager editors the same way, and make Cursor a thin specialization of a shared VS Code–compatible base so future IDEs reuse the same language → extensions/settings path.

## Non-goals

- Installing the VS Code application by default.
- Moving Serena (stays under `modules/languages/`; MCP language servers, not an IDE).
- Changing which language packs exist or how Copier enables `languages.*`.
- Adopting `programs.vscode` / `programs.cursor` (they overwrite user settings JSON).

## Current state

| Path | Role |
| --- | --- |
| `modules/languages/cursor.nix` | Project-local `.vscode/extensions.json`, settings, `cursor-sync-extensions` gated on `languages.*` |
| `home/cursor.nix` + `cursor-extensions.nix` | User-global Cursor install + common extensions under `~/.cursor/extensions` |
| `home/vscode-ext-lib.nix` | Marketplace packs (common + per-language) |
| `home/neovim.nix`, `home/nano.nix` | User-global editors |
| `modules/lib/project.nix` | `cursorUnwanted` / `cursorRecommendations` / `cursorLanguageIds` |

Cursor lives under `languages/` only because it reads `languages.*`. Neovim and nano are already IDEs/editors but live flat under `home/`.

## Target tree

```
home/ides/
  default.nix              # barrel: vscode, cursor, neovim, nano
  ext-lib.nix              # moved from home/vscode-ext-lib.nix
  vscode.nix               # shared VS Code–compatible Home Manager base
  vscode-extensions.nix    # common extensions → ~/.vscode/extensions
  cursor.nix               # Cursor-only: package wrapper, desktop, enable
  cursor-extensions.nix    # common extensions → ~/.cursor/extensions
  neovim.nix
  nano.nix

modules/ides/
  default.nix              # barrel
  lib.nix                  # language → settings / recommendation helpers
  vscode/
    settings.nix           # .vscode/settings.json from languages.*
    extensions.nix         # .vscode/extensions.json
    sync.nix               # sync script parameterized by extensionsDir
  cursor/
    default.nix            # thin: extensionsDir = ~/.cursor/extensions, enterShell

home.nix                   # imports ./home/ides (not individual editors)
modules/devenv.nix         # ./ides instead of ./languages/cursor.nix
```

`modules/languages/serena.nix` remains under languages.

## Home Manager behavior

### `vscode.enable` (default: **false**)

- Opt-in only. When false, do **not** install `pkgs.vscode` (or any VS Code GUI package).
- When true (future / explicit user choice): install the VS Code app and link **common** extensions under `~/.vscode/extensions`.
- Shared module code (extension lib, option shapes used by Cursor) may be imported by Cursor even when `vscode.enable` is false. Enabling Cursor must not install VS Code.

### `cursor.enable` (default: **true**)

- Imports / reuses the VS Code base for marketplace packs and any shared helpers.
- Cursor-only deltas:
  - `code-cursor` launcher (`--no-sandbox`, VMware Mesa/X11).
  - `.desktop` entry.
  - Common extensions under `~/.cursor/extensions`.
- Does not use `programs.cursor`.
- Existing `cursor.llmContext.*` / `cursor.ninerouter.*` options stay under the `cursor` namespace (files may move; option paths do not).

### Neovim / nano

- Move to `home/ides/` with unchanged behavior.
- No shared extension sync with VS Code/Cursor in this change.

## devenv behavior

### VS Code base (`modules/ides/vscode/`)

Owns project-local IDE config driven by `languages.*`:

1. Build recommendations and `unwantedRecommendations` (rename helpers away from `cursor*` toward vscode-oriented names; keep behavior).
2. Build language-gated `settings.json` content (nix always; rust/go/python/typescript when enabled).
3. Write `.vscode/extensions.json` via devenv `files`.
4. Provide a sync script parameterized by `extensionsDir` that:
   - symlinks selected **language** packs into `extensionsDir` when missing;
   - writes `.vscode/settings.json` when content changes.

Enabling a language installs the matching marketplace extensions for every IDE whose sync runs (same pack list, different `extensionsDir`).

### Cursor specialization (`modules/ides/cursor/`)

- Sets `extensionsDir` to `~/.cursor/extensions`.
- Wires script name `cursor-sync-extensions` and `enterShell` to run it.
- No duplicated settings/pack lists.

### Policy (unchanged)

- **Common** extensions: user-global via Home Manager.
- **Language** packs: project-local via devenv sync, not user-global.

## Library / naming

- Move `home/vscode-ext-lib.nix` → `home/ides/ext-lib.nix`; update imports.
- Extract settings construction from the current monolithic cursor module into `modules/ides/lib.nix` (or keep pure attr builders next to vscode settings).
- Rename in `modules/lib/project.nix` (and unit tests):
  - `cursorAlwaysRecommend` → `vscodeAlwaysRecommend` (or shared `ideAlwaysRecommend` if clearer)
  - `cursorLanguageIds` → `vscodeLanguageIds`
  - `cursorUnwanted` / `cursorRecommendations` → matching vscode names
- Update stale comments that still mention `cursor-languages.nix`.

## Docs

Update in the same session as the code (separate `docs:` commit when committing):

| Doc | Change |
| --- | --- |
| `docs/content/contributing.md` | Topical `modules/` / `home/` lists; generated-file table paths |
| `docs/content/architecture.md` | IDEs follow `modules/ides/`; language packs still from `languages.*` |
| `docs/content/tools.md` / `terminal.md` | Cursor paths; VS Code opt-in |
| `.gitignore` / `.gitignore.jinja` | Comment paths for generated `.vscode/extensions.json` |

## Tests

- Retarget `tests/unit/cursor.nix` to renamed project helpers (file may become `tests/unit/vscode.nix` or keep name if suites stay Cursor-facing).
- Home Manager eval / BATS that reference `home/cursor.nix` paths update to `home/ides/…`.
- No assertion that VS Code is installed unless a test explicitly sets `vscode.enable = true`.

## Migration / branch hygiene

- Work on `refactor/ides` in `.worktrees/refactor-ides` from `initial-development`.
- Drop accidental “checkpoint before checking out master” commits if any reappear.
- PRs target `initial-development` until release cut; GitHub default branch is `main`.

## Success criteria

1. `modules/languages/cursor.nix` is gone; devenv imports `modules/ides`.
2. `home.nix` imports `home/ides` only for editors (cursor, vscode, neovim, nano).
3. Cursor module does not re-list language packs or settings; it specializes the vscode base.
4. `vscode.enable` default false → no VS Code app on PATH / in `home.packages`.
5. Enabling a language still installs that language’s extensions under `~/.cursor/extensions` on `devenv shell`.
6. Docs and unit tests match the new paths and names.
