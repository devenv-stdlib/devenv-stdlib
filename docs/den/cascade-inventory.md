# Den cascade inventory (Phase 0)

**Status:** Phase 0 complete — naming only; no Den dependency.  
**ADR:** [0001-den-composition-model](../adr/0001-den-composition-model.md)  
**Smoke:** [phase-0-smoke.md](./phase-0-smoke.md)  
**Seed:** rewrite eval §2 + `modules/lib/project.nix` / `home/` on `initial-development`.

This table is the aspect/`includes` sketch before Phase 1 adds Den. Each row names a **candidate aspect**, how today’s enablement is expressed (`includes` vs **policy** vs **imperative**), primary files, and the **existing tests** that already encode cascade intent (golden set for later PRs).

---

## Legend

| Kind | Meaning for later Den work |
| --- | --- |
| **includes** | Should become an aspect `includes` edge (feature DAG) |
| **policy** | Resolve-time routing / guard / mutual exclusion |
| **imperative** | Script / activation / enterShell — policies may *bind*, not replace |
| **quirk / provides** | Structured data aggregated across aspects (`provides` / quirks) |

---

## A. Language fan-out (`languages.<lang>.enable` → project shell)

Canonical shape (python shown; rust / go / javascript / typescript mirror it):

```
python ──includes──► python-hooks
       ├───────────► python-ide-recs (+ cursor-sync on enterShell)
       ├───────────► python-serena
       ├───────────► python-debtmap
       └───────────► python-ci-matrix   # may stay quirk → versions-lib
```

| Aspect candidate | Kind | Today (files / mechanism) | Planned Den notes | Existing tests |
| --- | --- | --- | --- | --- |
| `python` / `rust` / `go` / `javascript` / `typescript` | **includes** hub | Copier / `devenv.local.nix` flips `languages.*.enable`; hub helpers in `modules/lib/project.nix` (`langOn`, `javascriptOn`) | One aspect per language; `includes` list replaces grepping `langOn` | `testLangOnMissingIsFalse`; language-specific rows below |
| `*-hooks` | **includes** | `modules/hooks/{python,rust,go,javascript}.nix` via `project.languageHooks` | Child aspects or class blocks on language aspect | `testLanguageHooksAllOff`, `testLanguageHooksRust`, `testLanguageHooksGo`, `testLanguageHooksPythonDefaultsToPyright`, `testLanguageHooksPythonTy`, `testLanguageHooksJavascriptPrettier`, `testLanguageHooksTypescriptPrettier` (`tests/unit/hooks.nix`) |
| always-on hooks | **policy** list | `project.alwaysOnHookNames` → `modules/hooks/common.nix` | Keep as always-on aspect or non-language policy; not language includes | `testAlwaysOnHookCount` |
| `*-debtmap` | **includes** + **quirk** | `debtmapLanguages` / `debtmapFiles` → `modules/debtmap/{default,hooks,lib}.nix` | Language includes debtmap; quirk feeds `.debtmap.toml` | `testDebtmapLanguages*`, `testDebtmapFiles` (`hooks.nix`); `testDebtmapSample*`, `testDebtmapGodObject*`, … (`tests/unit/debtmap.nix`) |
| `*-ide-recs` | **includes** + **quirk** | `vscodeRecommendations` / `vscodeUnwanted` / `vscodeLanguageIds` → `modules/ides/{lib,vscode,cursor}` | Quirk/`provides` of extension ids; enterShell sync stays imperative | `testVscodeUnwantedWhenLanguagesOff`, `testVscodeRecommendationsPython`, `testVscodeRecommendationsJavascriptOrTypescript` (`tests/unit/vscode.nix`) |
| `*-serena` | **includes** + **quirk** | `serenaLanguageServers` → `modules/languages/serena.nix` → `.serena/project.yml` | JS+TS share Serena `"typescript"` once (`javascriptOn`) | `testSerenaLanguageServersWhenLanguagesOff`, `testSerenaLanguageServersRust`, `testSerenaLanguageServersJavascriptAndTypescriptOnce`, `testSerenaLanguageServersPythonAndGo` (`tests/unit/serena.nix`) |
| `*-ci-matrix` | **quirk** (prefer) | `modules/languages/versions.nix` + `versions-lib.nix` + `catalog.json` | Quirk attrs for workflow generator; do **not** rewrite versions-lib first | `tests/unit/versions.nix` (`testResolvedVersions*`, catalog/patch); `tests/unit/workflow.nix`; `tests/unit/matrices.nix`; `tests/unit/problems.nix` |
| TypeScript bundler guard | **policy** | `typescriptBundlers` / `typescriptBundlerMissing` in `project.nix` + `modules/languages/default.nix` | Guard: only forward bundler aspects when TS enable + bundler set | `testTypescriptBundlers`, `testTypescriptBundlerMissing` |

**Integration asserts (same helpers):** `tests/integration/eval.nix` — languageHooks, debtmapLanguages, bundler missing, workflow runners.

---

## B. Cursor nested cascade (home)

```
cursor ──includes──► cursor-extensions
       └───────────► cursor-llm / mcp-stack
                         (mise/Nix CLIs, MCP upsert, rules, mcp-secrets-watch)
```

Today `cursor.llmContext.enable` **defaults to** `cursor.enable` — that default is an **includes** edge (or policy), not tribal knowledge in `cursor-llm.nix`.

| Aspect candidate | Kind | Today (files / mechanism) | Planned Den notes | Existing tests |
| --- | --- | --- | --- | --- |
| `cursor` | **includes** hub | `home/ides/cursor.nix` — package + desktop; default enable true | Phase 1 spike hub | (HM eval / bats below; no nix-unit aspect yet) |
| `cursor-extensions` | **includes** | `home/ides/cursor-extensions.nix` — common packs → `~/.cursor/extensions` when cursor on | Included by `cursor` | — |
| `cursor-llm` / `mcp-stack` | **includes** | `home/ides/cursor-llm.nix` — `llmContext.enable` default = `cursor.enable` | Explicit `cursor.includes` | `tests/home/cursor-llm.bats` |
| MCP catalog merge | **imperative** | `home/ides/mcp/*`, `merge-cursor-llm.sh`, `merge-lib.sh`; HM `home.activation.mergeCursorLlm` | Bind via policy; keep scripts | `cursor-llm.bats` |
| `mcp-secrets-watch` | **imperative** | `home/watch-mcp-secrets.sh` + systemd user unit | Same | `tests/home/watch-mcp-secrets.bats` |
| SecretSpec / `.env` load | **imperative** | `home/load-secrets.sh` (also used by `home-switch`) | Outside Den day one | `tests/home/load-secrets.bats` |

---

## C. Terminal provider (home)

```
terminal ──includes──► alacritty-quake  XOR  warp-quake
         (provider enum → mutually exclusive installs + GNOME binding + dash pin)
```

| Aspect candidate | Kind | Today (files / mechanism) | Planned Den notes | Existing tests |
| --- | --- | --- | --- | --- |
| `terminal` | **includes** hub + **policy** XOR | `home/terminal.nix` — `terminal.provider` = `alacritty` \| `warp` | Guard / mutually exclusive includes | `tests/unit/terminal.nix` (`testGnomeBindingF12`, `testGnomeBindingCtrlShiftF12`, `testWarpTomlHonorPs1`, `testDesktopIds`, `testQuakeExtensionUuid`, …); `tests/home/terminal-lib.bats` → `tests/home/eval.nix` |
| `alacritty-quake` / `warp-quake` | **includes** (exclusive) | `home/alacritty.nix` / `home/warp.nix` via `mkIf` on provider | One include active | Pure helpers in `home/terminal-lib.nix` covered by unit + bats above |

---

## D. Cross-lifetime IDE sync bridge

```
aspect python (etc.)
  project.*   → devenv language + hooks + .vscode recommendations
  homeManager.* → only if we ever promote user-global pieces; language packs stay project-scoped
```

GUI terminal / Cursor **app** stay out of devenv PATH. Language packs are project-scoped sync into user dirs.

| Aspect / quirk | Kind | Today | Planned Den notes | Existing tests |
| --- | --- | --- | --- | --- |
| Project IDE recommendations | **quirk** + **includes** | `modules/ides/vscode` writes `.vscode/extensions.json` from `project.vscode*` | Same as `*-ide-recs` | `tests/unit/vscode.nix` |
| `cursor-sync-extensions` | **imperative** | `modules/ides/cursor` — `enterShell` add-only sync under `~/.cursor/extensions` | Policy/script bind; shared packs `home/ides/ext-lib.nix` | Covered indirectly via ide module design; expand in Phase 2 |
| Common editor extensions (devenv, nix-ide) | home **includes** | `cursor-extensions.nix` / `vscode-extensions.nix` when app enable | Stay on cursor/vscode aspects | — |
| VS Code app opt-in | separate aspect | `home/ides/vscode.nix` default **false** | Not nested under cursor | — |

---

## E. mise / non-nix catalog

| Aspect / concern | Kind | Today | Planned Den notes | Existing tests |
| --- | --- | --- | --- | --- |
| non-nix catalog resolve | **imperative** + pure lib | `modules/non-nix/lib.nix`, `catalog.toml`, edit scripts | Stay outside Den composition; CLIs consumed by cursor-llm / debtmap | `tests/unit/non-nix.nix` (`testNonNixMissingAttrStaysMise`, `testNonNixVersionAndHomepagePromote`, `testNonNixShippedCatalogNonEmpty`, …) |
| Project mise | **imperative** | `modules/mise/default.nix` — `mise.toml`, `mise:install` before enterShell | Not an aspect includes target day one | — |
| User mise | **imperative** | `home/mise.nix` — conf.d + `miseInstallNonNix` activation | Ordered before MCP merge | `tests/home/bashrc-d.bats` (mise activate lands in bashrc.d) |

---

## F. `project.nix` helpers → planned aspect / `provides` quirks (W0.3)

| Helper (`modules/lib/project.nix`) | Maps to |
| --- | --- |
| `langOn` / `javascriptOn` | Context / enable predicates on language aspects |
| `languageHooks` | `provides` quirk or class config for `*-hooks` includes |
| `debtmapLanguages` / `debtmapFiles` | Debtmap quirk + hook files regex |
| `alwaysOnHookNames` | Always-on hooks aspect / policy list |
| `typescriptBundlers` / `typescriptBundlerMissing` | Guard policy on typescript aspect |
| `vscodeAlwaysRecommend` / `vscodeLanguageIds` / `vscodeRecommendations` / `vscodeUnwanted` | IDE recommendation quirks (`provides`) |
| `serenaAlwaysLanguageServers` / `serenaLanguageServers` | Serena quirk (`provides`) |

Pure helpers may remain as Nix functions consumed by aspects until Phase 4 collapses god-tables.

---

## G. Pre-Den entrypoints (baseline)

| Entrypoint | Pre-Den target | Phase that may change it |
| --- | --- | --- |
| `scripts.home-switch` in `devenv.nix` | `home-manager switch -f "$DEVENV_ROOT/home.nix"` | Phase 1 sibling or Phase 4 Den-only |
| devenv modules import | `devenv.yaml` → `./modules` | Phase 2–3 aspect shims |
| Copier | writes `devenv.local.nix` language flags | Stays; Phase 4 only if answers must select includes |

---

## Acceptance checklist (Phase 0)

- [x] Languages fan-out inventoried (hooks, debtmap, IDE, serena, CI matrix, bundler guard)
- [x] Cursor → LLM / MCP inventoried (includes vs imperative)
- [x] Terminal provider XOR inventoried
- [x] IDE sync bridge (project vs home) inventoried
- [x] mise / non-nix inventoried
- [x] `project.nix` → aspect/quirk map (W0.3)
- [x] Existing nix-unit / home bats mapped as cascade golden set
- [x] ADR cites abort criteria + den-only ecosystem ranking
