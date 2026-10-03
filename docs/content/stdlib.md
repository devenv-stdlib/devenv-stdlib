# Standard library

`stdlib/` is the framework tools and presets import. The directory name stays `stdlib`. A top-level `lib/` is not the public import path.

## Import path

Nix in this repo imports `stdlib/default.nix`, or a shim that re-exports it. The flake publishes the same attrset as `stdlib`:

```nix
inputs.devenv4monorepo.url = "github:thedrow/devenv4monorepo";
# stdlib = inputs.devenv4monorepo.stdlib;
```

Read `stdlib.version`, `stdlib.apiVersion`, `stdlib.den.load`, and `stdlib.devenv.load` from that output. Copier still copies `stdlib/` into a generated tree; a later packaging change will switch generated flakes to this input instead of vendoring the sources.

## Version and stability

`stdlib/version.nix` holds `version`. `apiVersion` is that version's major component (`0` while the version is `0.y.z`).

On a release, semantic-release runs `includes/update/stdlib-version.sh` and commits the rewritten `version`. `@semantic-release/git` records `stdlib/version.nix`.

A breaking change to exported attribute paths uses the commit subject `feat(stdlib)!:` (a `BREAKING CHANGE:` footer is the same signal). semantic-release then bumps the major, and `apiVersion` follows. New attributes that keep the old paths use `feat(stdlib):`.

`tests/unit/stdlib-api.nix` snapshots every exported path. An API edit that does not update that list fails nix-unit.

## Helpers

Pure helpers live under `stdlib/`. The old paths re-export them:

| Implementation | Shim |
| --- | --- |
| `stdlib/project.nix` | `modules/lib/project.nix` |
| `stdlib/versions.nix` | `modules/languages/versions-lib.nix` |
| `stdlib/terminal.nix` | `home/terminal-lib.nix` |
| `stdlib/ide-ext.nix` | `home/ides/ext-lib.nix` |
| `stdlib/catalog.nix` | `modules/non-nix/lib.nix` |
| `stdlib/debtmap.nix` | `modules/debtmap/lib.nix` |

`mkTool` and `mkPreset` are not part of this export.

## Categories

`stdlib/categories.nix` is a tree. Each node has one cardinality. The names in the tree are hyphenated compounds: exactly one, any of, zero or one, and bundle. Resolve a node with a dotted path such as `lang.python.linters` or `harness`. Sibling exclusion, when presets grow it, stays inside that node.

Profilers are not one flat node. `profilers.cpu` and `profilers.memory` are separate. `valgrind` and `cargo-valgrind` are registered on `profilers.memory`. CPU names (`samply`, `py-spy`, `cargo-flamegraph`, `pprof`) sit on `profilers.cpu`. A name in the tree is not a tool module.

`harness` uses the exactly one cardinality. A multi-harness preset may switch that node to `any-of`. The registered names are `opencode`, `claude-code`, and `codex`.

`ai-gateways` is zero-or-one. `9router` and `litellm` are shelved and are not registered tools.

## Coding harnesses

`stdlib/harness.nix` is the shared foundation from [issue #32](https://github.com/thedrow/devenv4monorepo/issues/32): option shapes, a config path under `$HOME`, install kinds (`nix`, `catalog`, `self`), and a split between a devenv `project` payload and a Home Manager payload.

`secretEnv` entries are environment variable names. A literal is rejected. Values are not written into the Nix store.

OpenCode, Claude Code, and Codex product modules are [issue #33](https://github.com/thedrow/devenv4monorepo/issues/33), [issue #34](https://github.com/thedrow/devenv4monorepo/issues/34), and [issue #35](https://github.com/thedrow/devenv4monorepo/issues/35). This file does not install them. Follow-up tools land at `tools/harness/<name>.nix`.

## Loaders

`stdlib.discover` lists `.nix` files under the directories you pass. It skips names that start with `_`.

`stdlib.den.load` and `stdlib.devenv.load` return module lists for the Den flake and the devenv evaluator. Both return an empty list until tool and preset lowering exists, so callers can already concatenate the result.

## Compat shims

Existing tests and modules keep the old import paths. The shims forward every argument. A later cleanup is the first change allowed to delete them and retarget those tests.
