# IDEs module layout and VS Code → Cursor inheritance

## Goal

Move editor/IDE wiring out of `modules/languages/` into a first-class `ides` category, regroup Home Manager editors the same way, and make Cursor a thin specialization of a shared VS Code–compatible base so future IDEs reuse the same language → extensions/settings path.

Also own **MCP registration** in the IDE/harness layer: one shared catalog of MCP servers, merged into each harness’s config (Cursor today; Claude Code / Codex / other harnesses later).

## Non-goals

- Installing the VS Code application by default.
- Changing Serena’s **project** config (`modules/languages/serena.nix` → `.serena/project.yml`); that stays language-gated. Only the **MCP server entry** (how Serena is registered with an IDE/harness) moves into the shared MCP catalog.
- Changing which language packs exist or how Copier enables `languages.*`.
- Adopting `programs.vscode` / `programs.cursor` (they overwrite user settings JSON).
- Implementing Claude Code / Codex / Cortex harnesses in this change (layout and catalog must make them additive).

## Current state

| Path | Role |
| --- | --- |
| `modules/languages/cursor.nix` | Project-local `.vscode/extensions.json`, settings, `cursor-sync-extensions` gated on `languages.*` |
| `home/cursor.nix` + `cursor-extensions.nix` | User-global Cursor install + common extensions under `~/.cursor/extensions` |
| `home/vscode-ext-lib.nix` | Marketplace packs (common + per-language) |
| `home/neovim.nix`, `home/nano.nix` | User-global editors |
| `home/llm-context.nix` | Cursor-only: MCP upsert into `~/.cursor/mcp.json`, RTK hooks/permissions, Headroom/Serena CLIs, optional 9Router |
| `home/merge-cursor-llm.sh` | Merge helpers for Cursor `hooks.json` / `mcp.json` / `permissions.json` |
| `modules/lib/project.nix` | `cursorUnwanted` / `cursorRecommendations` / `cursorLanguageIds` |

Cursor lives under `languages/` only because it reads `languages.*`. Neovim and nano are already IDEs/editors but live flat under `home/`. MCP definitions are embedded in Cursor activation rather than a reusable catalog.

## Target tree

```
home/ides/
  default.nix              # barrel: vscode, cursor, neovim, nano, mcp
  ext-lib.nix              # moved from home/vscode-ext-lib.nix
  vscode.nix               # shared VS Code–compatible Home Manager base
  vscode-extensions.nix    # common extensions → ~/.vscode/extensions
  cursor.nix               # Cursor-only: package wrapper, desktop, enable
  cursor-extensions.nix    # common extensions → ~/.cursor/extensions
  cursor-llm.nix           # was llm-context.nix: RTK/hooks/9Router + Cursor MCP merge
  neovim.nix
  nano.nix
  mcp/
    default.nix            # shared MCP catalog (servers, wrappers, secret-gated optionals)
    merge-lib.sh           # generic mcp.json upsert/remove (harness-agnostic core)
    # Cursor-specific merge entry points may wrap merge-lib.sh

modules/ides/
  default.nix              # barrel
  lib.nix                  # language → settings / recommendation helpers
  vscode/
    settings.nix           # .vscode/settings.json from languages.*
    extensions.nix         # .vscode/extensions.json
    sync.nix               # sync script parameterized by extensionsDir
  cursor/
    default.nix            # thin: extensionsDir = ~/.cursor/extensions, enterShell

home.nix                   # imports ./home/ides (not individual editors / llm-context)
modules/devenv.nix         # ./ides instead of ./languages/cursor.nix
```

`modules/languages/serena.nix` remains under languages (project `language_servers` only).

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

### MCP catalog (`home/ides/mcp/`)

Shared definitions for MCP servers the template ships:

| Server | Notes |
| --- | --- |
| serena | CLI; `--context ide` (or harness-specific context later) |
| headroom | Official MCP; omitted when 9Router / gateway path says so |
| context7 | Remote URL |
| docker | Rootless Docker socket wrapper |
| brave-search | Optional; SecretSpec / `.env` |
| firecrawl | Optional; SecretSpec / `.env` |

Rules:

1. **One catalog** builds the upsert/remove payloads (commands, args, URLs). Wrappers (docker/brave/firecrawl scripts) live with the catalog.
2. **Each harness** only chooses: config path (e.g. `~/.cursor/mcp.json`), when to enable (`cursor.llmContext.enable`), and harness-specific removals (e.g. drop `headroom` when 9Router is on).
3. **Later harnesses** (Claude Code, Codex, Cortex, …) add a thin merge module that points the same catalog at that product’s MCP config. No re-listing of server commands.
4. Cursor-only concerns stay in `cursor-llm.nix`: RTK rewrite hook, `permissions.json` allowlist, Ponytail/Headroom/RTK rules, 9Router unit and dashboard key flow. Those are not part of the shared MCP catalog.
5. **User-owned entries are preserved.** Users may add their own MCP servers (and keep ones we do not ship). Merge only **upserts** catalog keys and **removes** keys we explicitly retire (e.g. former `github` MCP, or `headroom` when 9Router is on). Never replace the whole `mcpServers` object or delete unknown keys. Same policy as today’s `merge-cursor-llm.sh`.

Merge scripts: extract a harness-agnostic `mcp.json` upsert/remove core from `merge-cursor-llm.sh`; Cursor keeps a thin wrapper for hooks/permissions and for calling merge with `$HOME/.cursor/mcp.json`.

### Neovim / nano

- Move to `home/ides/` with unchanged behavior.
- No shared extension sync with VS Code/Cursor in this change.
- No MCP registration (they are not agent harnesses).

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
- **MCP servers**: user-global via Home Manager harness merge (not devenv), same as today.
- **User additions win coexistence:** users may install their own marketplace extensions (under `~/.cursor/extensions`, `~/.vscode/extensions`, or via the IDE UI) and add their own MCP servers. Our sync **only adds missing catalog/language links**; it must not remove unknown extension directories or wipe user MCP entries. Project `.vscode/extensions.json` remains recommendations (plus our unwanted list for disabled packs), not an exclusive lock on the user’s editor.

## Library / naming

- Move `home/vscode-ext-lib.nix` → `home/ides/ext-lib.nix`; update imports.
- Move `home/llm-context.nix` → `home/ides/cursor-llm.nix` (or split catalog vs Cursor activation as above).
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
| `docs/content/architecture.md` | IDEs follow `modules/ides/`; MCP catalog under `home/ides/mcp/`; language packs still from `languages.*` |
| `docs/content/tools.md` / `terminal.md` | Cursor paths; VS Code opt-in; MCP owned by harness layer |
| `.gitignore` / `.gitignore.jinja` | Comment paths for generated `.vscode/extensions.json` |

## Tests

- Retarget `tests/unit/cursor.nix` to renamed project helpers (file may become `tests/unit/vscode.nix` or keep name if suites stay Cursor-facing).
- Home Manager eval / BATS that reference `home/cursor.nix` / `llm-context.nix` / `merge-cursor-llm.sh` update to `home/ides/…`.
- `tests/home/cursor-llm.bats` keeps behavior coverage; paths and any extracted merge-lib tests updated.
- No assertion that VS Code is installed unless a test explicitly sets `vscode.enable = true`.

## Migration / branch hygiene

- Work on `refactor/ides` in `.worktrees/refactor-ides` from `initial-development`.
- Drop accidental “checkpoint before checking out master” commits if any reappear.
- PRs target `initial-development` until release cut; GitHub default branch is `main`.

## Success criteria

1. `modules/languages/cursor.nix` is gone; devenv imports `modules/ides`.
2. `home.nix` imports `home/ides` only for editors and Cursor LLM/MCP (no flat `home/cursor.nix` / `llm-context.nix`).
3. Cursor module does not re-list language packs or settings; it specializes the vscode base.
4. `vscode.enable` default false → no VS Code app on PATH / in `home.packages`.
5. Enabling a language still installs that language’s extensions under `~/.cursor/extensions` on `devenv shell`.
6. MCP server commands/URLs live in `home/ides/mcp/`; Cursor only merges into `~/.cursor/mcp.json` (existing servers and secret-gated Brave/Firecrawl still work). User-added MCP keys and extension dirs survive merge/sync.
7. Docs and unit tests match the new paths and names.
