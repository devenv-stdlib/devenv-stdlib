# IDEs Module Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move IDE wiring into `modules/ides/` and `home/ides/`, make Cursor inherit a VS Code base, and extract a shared MCP catalog that preserves user additions.

**Architecture:** Shared vscode devenv modules own language → extensions/settings/sync; Cursor only sets `~/.cursor/extensions` and enterShell. Home Manager editors live under `home/ides/`; MCP definitions under `home/ides/mcp/` with Cursor merge into `~/.cursor/mcp.json`.

**Tech Stack:** Nix (devenv + Home Manager), bash merge helpers, nix-unit, BATS.

**Spec:** `docs/superpowers/specs/2026-09-09-ides-module-design.md`

## Global Constraints

- `vscode.enable` default false — do not install the VS Code app unless enabled.
- `cursor.enable` default true; option paths `cursor.llmContext.*` / `cursor.ninerouter.*` unchanged.
- Never wipe user MCP keys or unknown extension directories (upsert/add-only sync).
- Serena `.serena/project.yml` stays in `modules/languages/serena.nix`.
- One topic per commit; separate `docs:` commit for user-facing docs.
- Work only in `.worktrees/refactor-ides` on `refactor/ides`.

---

### Task 1: Rename project helpers + unit tests

**Files:**
- Modify: `modules/lib/project.nix`
- Rename/modify: `tests/unit/cursor.nix` → `tests/unit/vscode.nix`
- Modify: `tests/unit/default.nix`

- [ ] Rename `cursorAlwaysRecommend` → `vscodeAlwaysRecommend`, `cursorLanguageIds` → `vscodeLanguageIds`, `cursorUnwanted` → `vscodeUnwanted`, `cursorRecommendations` → `vscodeRecommendations`
- [ ] Update unit tests and suite import
- [ ] Run: `nix-unit tests/unit/default.nix` (or via devenv)
- [ ] Commit: `refactor: rename Cursor project helpers to vscode*`

### Task 2: modules/ides (devenv)

**Files:**
- Create: `modules/ides/{default.nix,lib.nix,vscode/{extensions.nix,settings.nix,sync.nix},cursor/default.nix}`
- Delete: `modules/languages/cursor.nix`
- Modify: `modules/devenv.nix`, `.gitignore`

- [ ] Extract settings/selected packs into `modules/ides/lib.nix`
- [ ] VS Code modules write `.vscode/extensions.json` and parameterized sync
- [ ] Cursor sets extensionsDir `$HOME/.cursor/extensions`, script `cursor-sync-extensions`, enterShell
- [ ] Wire `./ides` in devenv barrel; remove languages/cursor import
- [ ] Commit: `refactor: move devenv Cursor wiring into modules/ides`

### Task 3: home/ides editors + VS Code base

**Files:**
- Create: `home/ides/{default.nix,ext-lib.nix,vscode.nix,vscode-extensions.nix,cursor.nix,cursor-extensions.nix,neovim.nix,nano.nix}`
- Delete: `home/{cursor.nix,cursor-extensions.nix,vscode-ext-lib.nix,neovim.nix,nano.nix}`
- Modify: `home.nix`, `includes/update/non-nix.sh`, `tests/update.bats`

- [ ] Move/adapt files; `vscode.enable` default false installs nothing; when true links common exts to `~/.vscode/extensions` and installs `pkgs.vscode` only if we choose install — spec: when true install app + common exts. Implement that.
- [ ] Cursor imports shared ext-lib; Cursor-only package/desktop/exts under `~/.cursor/extensions`
- [ ] Commit: `refactor: regroup Home Manager editors under home/ides`

### Task 4: MCP catalog + cursor-llm

**Files:**
- Create: `home/ides/mcp/{default.nix,merge-lib.sh}`, `home/ides/cursor-llm.nix`, `home/ides/merge-cursor-llm.sh` (or keep merge next to cursor-llm)
- Delete: `home/llm-context.nix` (and old merge path after updates)
- Modify: tests, 9router scripts env paths

- [ ] Extract generic mcp upsert into `merge-lib.sh`; Cursor wrapper sources it
- [ ] Catalog builds server upsert payloads; cursor-llm merges to `~/.cursor/mcp.json`
- [ ] Update BATS paths; keep behavior
- [ ] Commit: `refactor: extract shared MCP catalog under home/ides/mcp`

### Task 5: Docs

**Files:** `docs/content/{contributing,architecture,tools,terminal}.md`

- [ ] Update paths and VS Code opt-in / MCP catalog notes
- [ ] Commit: `docs: document home/ides and modules/ides layout`

### Task 6: Verify

- [ ] `nix-unit` suite + `bats tests/home/cursor-llm.bats` (+ related)
- [ ] Confirm no `modules/languages/cursor.nix` or flat `home/cursor.nix` / `llm-context.nix`
