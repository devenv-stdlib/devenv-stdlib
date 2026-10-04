# Standard library

`stdlib/` is the framework tools and presets import. The directory name stays `stdlib`. A top-level `lib/` directory is not the public import path. The flake output `lib` is the same attrset as `stdlib`.

## Import path

Nix in this repo imports `stdlib/default.nix`, or a shim that re-exports it. `flake.nix` evaluates `packaging/den-outputs.nix` and publishes that attrset as both `stdlib` and `lib`:

```nix
inputs.devenv-stdlib.url = "github:thedrow/devenv4monorepo/<commit>";
# inputs.devenv-stdlib.stdlib.version
# inputs.devenv-stdlib.stdlib.apiVersion
# inputs.devenv-stdlib.stdlib.mkTool
# inputs.devenv-stdlib.stdlib.den.load
# inputs.devenv-stdlib.stdlib.devenv.load
# inputs.devenv-stdlib.lib  — same attrset as stdlib
```

`mkPreset` stays in `stdlib/preset.nix`. It is not an attribute of this attrset.

Generated monorepos pin that GitHub input. Copier does not copy `stdlib/` or `packaging/`.

## Version and stability

`stdlib/version.nix` holds `version`. `apiVersion` is that version's major component (`0` while the version is `0.y.z`).

On a release, semantic-release runs `includes/update/stdlib-version.sh` and commits the rewritten `version`. `@semantic-release/git` records `stdlib/version.nix`.

A breaking change to exported attribute paths needs a `BREAKING CHANGE:` footer. semantic-release uses the angular preset, which reads that footer and bumps the major, so `apiVersion` follows. New attributes that keep the old paths use `feat(stdlib):`.

`tests/unit/stdlib-api.nix` snapshots every exported path. An API edit that does not update that list fails nix-unit.

## Helpers

`tests/integration/default.nix` copies `modules/lib/project.nix` and `modules/languages/versions-lib.nix` into the Nix store as single files and evaluates those copies on their own. Those two bodies stay in the historical files. `stdlib/project.nix` and `stdlib/versions.nix` re-export them.

The other pure helpers live under `stdlib/`. The old paths re-export them:

| Implementation | Re-export |
| --- | --- |
| `modules/lib/project.nix` | `stdlib/project.nix` |
| `modules/languages/versions-lib.nix` | `stdlib/versions.nix` |
| `stdlib/terminal.nix` | `home/terminal-lib.nix` |
| `stdlib/ide-ext.nix` | `home/ides/ext-lib.nix` |
| `stdlib/catalog.nix` | `modules/non-nix/lib.nix` |
| `stdlib/debtmap.nix` | `modules/debtmap/lib.nix` |

`mkTool` is `stdlib/tool.nix`, exported as `stdlib.mkTool`. `mkPreset` is not part of this export.

## Preset attrpaths

Building-block presets keep the hierarchy of their tools. Identity is a nested attrpath (`path = [ "python" "lint" "ruff" ]` → `presets.python.lint.ruff` and Den aspect `python.lint.ruff`), not a flat string name. Compose with attrpath refs:

```nix
includes = with presets; [
  python.lint.ruff
  terminal.quake
];

tools = [ tools.python.lint.pyright ];
```

`mkPreset includes` and `tools` reject string literals. Prefer explicit `tools.<attrpath>` over `with tools;` when a binding would shadow the registry. `stdlib/preset.nix` exports `mkRef` / `refsFromPaths` for the `with presets; …` registry.

## Categories

`stdlib/categories.nix` is a tree. Each node has one cardinality. The names in the tree are hyphenated compounds: exactly one, any of, zero or one, and bundle. Resolve a node with a dotted path such as `lang.python.linters` or `harness`. Sibling exclusion, when presets grow it, stays inside that node.

Profilers are not one flat node. `profilers.cpu` and `profilers.memory` are separate. `valgrind` and `cargo-valgrind` are registered on `profilers.memory`. CPU names (`samply`, `py-spy`, `cargo-flamegraph`, `pprof`) sit on `profilers.cpu`. A name in the tree is not a tool module.

`harness` uses the exactly one cardinality. A multi-harness preset may switch that node to `any-of`. The registered names are `opencode`, `claude-code`, and `codex`.

`ai-gateways` is zero-or-one. `9router` and `litellm` are shelved and are not registered tools.

## Category policies

`stdlib/category-policy.nix` (exported as `stdlib.categoryPolicy`) declares **category-wide** prerequisites once per namespaced language or service category. Enabling any preset under `<lang>.*` or tool under `lang.<lang>.*` requires that category’s toolchain to be available — leaves do not copy the same `when` / `requires` clause. Service categories use the same pattern with policy id `services.<id>` against `services.<id>.enable`.

**Wired languages and services:** every devenv `languages.*` / `services.*` id from `stdlib/devenv-supported.nix` (cachix/devenv v2.4.0 modules) has a `lang.<id>` (with `linters` child) or `services.<id>` node and a matching policy. A language is available when `languages.<id>.enable` is true **or** `stdlib.categoryPolicies.<id>.available = true`. A service is available when `services.<id>.enable` is true **or** `stdlib.categoryPolicies."services.<id>".available = true`. Descendants inherit. Leaf-specific `requires` (for example `typescript.bundler`) stay on the leaf.

Empty directory scaffolds live under `tools/lang/<id>/`, `presets/<id>/`, and `presets/services/<id>/` (README markers only; loaders skip `_*.nix` and non-`.nix` files). Framework tool leaves exist only for languages that already ship presets (python, rust, go, javascript, typescript, …).

Shared JS/TS presets under `javascript.*` (`javascript.lint.prettier`, `javascript.ide`, `javascript.serena`) set `categoryPolicy = "javascript-or-typescript"` so they inherit when either language is available. JavaScript-only leaves (`javascript.debtmap`, `javascript.supported`) keep the plain `javascript` policy.

| Surface | Enforcement |
| --- | --- |
| Presets (`python.lint.ruff`, `rust.lint.clippy`, `go.lint.gofmt`, …) | Omit `when` → inherit category `available` as `when`. Category `requires` are always appended (strict throw / warn+inert via existing `realize`). Optional `categoryPolicy` on a leaf overrides the path-derived policy id. |
| Tools (`tools.ruff` under `lang.python.linters`, …) | When `tools.<name>.enable`, module `assertions` require category availability. |

To add another language after a devenv bump: append the id to `stdlib/devenv-supported.nix` and add the matching `tools/lang/<id>/` + `presets/<id>/` README scaffolds. Policies and `lang.<id>` nodes are generated from that list.

## Unused category warnings

`stdlib/category-warnings.nix` (exported as `stdlib.categoryWarnings`) warns when a language or service category is **available** but **unused**: no enabled tool under that category prefix and no applied preset under the matching attrpath.

| Category path | Preset attrpath | Availability |
| --- | --- | --- |
| `lang.<id>` | `<id>.*` | `languages.<id>.enable` or `categoryPolicies.<id>.available` |
| `lang.<id>.linters` | `<id>.lint.*` | same as `lang.<id>` |
| `services.<id>` | `services.<id>.*` | `services.<id>.enable` or `categoryPolicies."services.<id>".available` |

Warnings go through module `warnings`, `stdlib.log.warn'` during the status inventory, and the report section **Unused available categories**. Opt out with `stdlib.categoryWarnings.enable = false`. Optional tool inventory: `stdlib.categoryWarnings.toolIndex` (`[ { name, category, enable } ]`) so enabled tools count as usage.

## Coding harnesses

`stdlib/harness.nix` is the shared foundation from [issue #32](https://github.com/thedrow/devenv4monorepo/issues/32): option shapes, a config path under `$HOME`, install kinds (`nix`, `catalog`, `self`), and a split between a devenv `project` payload and a Home Manager payload.

`secretEnv` entries are environment variable names. A literal is rejected. Values are not written into the Nix store.

OpenCode, Claude Code, and Codex product modules are [issue #33](https://github.com/thedrow/devenv4monorepo/issues/33), [issue #34](https://github.com/thedrow/devenv4monorepo/issues/34), and [issue #35](https://github.com/thedrow/devenv4monorepo/issues/35). This file does not install them. Follow-up tools land at `tools/harness/<name>.nix`.

## Logging

`stdlib.log` is the only logging API for tools and presets (`trace` / `debug` / `info` / `warn` / `warnIf` and the `'` variants). It wraps [nix-log](https://github.com/rvolosatovs/nix-log) privately via `mkLog`. Do **not** import `inputs.nix-log` or the raw nix-log library — nix-log is an implementation detail of `stdlib/log.nix`. Level is gated by `NIX_LOG` (default `WARN`).

## Status report

`stdlib.report` builds an inventory of applied presets (nested attrpaths like `python.lint.ruff`), enabled tools, enabled `git-hooks` / pre-commit hooks, and the CI build matrix. Tool inventory walks nested `tools.*` trees and lists every attrs leaf with a bool `enable` (today `tools.<leaf>.enable`; dotted paths if enable ever nests). After **Enabled tools**, the summary prints `Use navi <tool name> to understand its usage.` — each stdlib tool leaf has a matching sheet in `cheats/<leaf>.cheat` (first tag = leaf name; `NAVI_PATH` prepends `cheats/` in `devenv shell`). The devenv loader forces that summary through module `warnings` and a Nix-built `enterShell` `printf` (no wrapper scripts). Toggle with `stdlib.report.enable` and `stdlib.report.enterShell`.

The language/OS `test.yml` matrix strategy is the composable preset `presets/ci/github_actions/language-matrix.nix` (attrpath `ci.github_actions.language-matrix`).

## Loaders

`stdlib.discover` lists `.nix` files under the directories you pass. It skips names that start with `_`.

`stdlib.den.load` lowers **global** `tools/**/*.nix` (Home Manager payloads) into Den aspect modules. A missing directory still yields an empty list, so callers can concatenate the result. `stdlib.devenv.load` lowers **local** tools (`project` payloads via `applyLocal`) plus thin presets under `presets/` — never imports Den. Prefer `{ presets = [...]; tools = [...]; }`. A bare list of `presets/<lang>` roots still works. If a sibling `tools/` directory exists, the loader infers it so thin presets can resolve `tools.<attrpath>` refs.

## No compat shims (pre-release)

There is no released public API yet, so empty re-export shims for old
`modules/hooks/*.nix`, `modules/ides/{cursor,vscode}`, and
`modules/languages/serena.nix` paths are **not** kept. Callers use
`presets/<lang>/<category>/*.nix` via `stdlib.devenv.load` (and `modules/ides/lib.nix`
for shared IDE helpers). Do not reintroduce dead shim files for paths that
never shipped.

## What Copier writes

`copier copy --trust` renders `consumer-flake.nix.jinja`, then a task moves that file to `flake.nix`. The publisher `flake.nix`, `flake.lock`, `stdlib/`, and `packaging/` stay here (`copier.yml` `_exclude`). `--trust` is required because that move is a Copier task.

The generated input is pinned to the template commit Copier recorded:

```nix
devenv-stdlib.url = "github:thedrow/devenv4monorepo/{{ _commit }}";
nixpkgs.follows = "devenv-stdlib/nixpkgs";
```

`copier update --trust` moves `_commit` and that pin together. Den outputs still build from the generated tree (`root = ./.`), so copied `modules/` and `home/` stay local. `mkTool` and `mkPreset` come from the pin.

## Presets this template enables

`presets/omer.nix` is the selection. It calls `mkPreset` from `stdlib/preset.nix`. Its HM `includes` are cohesive bundles via attrpaths:

`terminal.quake`, `terminal.alacritty-atuin`, `ide`, `ide.coderabbit`, `host.hm-only-guard`.

Language support is **not** a megapreset named Python/Rust/…. Local language leaves are first-class `mkTool` modules under `tools/lang/<lang>/…` (same public API as global tools: `tools.<name>.enable`). Thin framework presets under `presets/<lang>/<category>/` keep attrpath identity (`python.lint.ruff`, `rust.lint.rustfmt`, …) and declare `tools = [ tools.python.lint.ruff ]` (plus an explicit `when` when needed); language gating comes from the category policy, not a copied `when` on every leaf. When applied, thin presets set `tools.<name>.enable = true`. Non-tool presets (serena, debtmap, ide, supported, bundler, ci presets, fixtures, …) stay as presets. Copier still decides which languages are on; disable one building block with `presets.python.lint.ruff.enable = false`. Opinionated multi-tool stacks belong in the consumer repo (see `presets/examples/`).

## Community tools and presets

Tool files under `tools/` are Home Manager modules. They call `stdlib/tool.nix` with `install.kind` (`nix`, `catalog`, `hm-program`, `vscode-extension`, or `docker-image`) and `upgrade` (`flake`, `catalog`, or `self`). `stdlib.den.load` reads that tree.

Preset files under `presets/` call `mkPreset` from `stdlib/preset.nix` (`path`, `when`, `requires`, `tools`, `includes`). Default is one preset per tool; bundle only when tools must ship together. `includes` takes attrpath refs (`with presets; [ python.lint.ruff ]`); `tools` takes tool attrpath refs (`tools = [ tools.python.lint.pyright ]`), not string literals. Prefer explicit `tools.<attrpath>` over `with tools;` when a `python` (or other) binding would shadow the registry. `mkPreset` is not on the flake `stdlib` attrset.
