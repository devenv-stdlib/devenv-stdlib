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

A breaking change to exported attribute paths uses the commit subject `feat(stdlib)!:` (a `BREAKING CHANGE:` footer is the same signal). semantic-release then bumps the major, and `apiVersion` follows. New attributes that keep the old paths use `feat(stdlib):`.

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
```

`mkPreset includes` rejects string literals. `stdlib/preset.nix` exports `mkRef` / `refsFromPaths` for the `with presets; …` registry.

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

`stdlib.den.load` lowers `tools/**/*.nix` into Den aspect modules. A missing directory still yields an empty list, so callers can concatenate the result. `stdlib.devenv.load` stays an empty list until preset project payloads exist.

## Compat shims

Existing tests and modules keep the old import paths. Re-exports forward every argument. A later cleanup is the first change allowed to delete them and retarget those tests.

## What Copier writes

`copier copy --trust` renders `consumer-flake.nix.jinja`, then a task moves that file to `flake.nix`. The publisher `flake.nix`, `flake.lock`, `stdlib/`, and `packaging/` stay here (`copier.yml` `_exclude`). `--trust` is required because that move is a Copier task.

The generated input is pinned to the template commit Copier recorded:

```nix
devenv-stdlib.url = "github:thedrow/devenv4monorepo/{{ _commit }}";
nixpkgs.follows = "devenv-stdlib/nixpkgs";
```

`copier update --trust` moves `_commit` and that pin together. Den outputs still build from the generated tree (`root = ./.`), so copied `modules/` and `home/` stay local. `mkTool` and `mkPreset` come from the pin.

## Presets this template enables

`presets/omer.nix` is the selection. It calls `mkPreset` from `stdlib/preset.nix`. Its `includes` are names:

`terminal-quake`, `alacritty-atuin`, `ide`, `host-hm-only-guard`, `python`, `rust`, `go`, `javascript`, `typescript`.

Language names stay gated by each preset's `when` (`languages.<lang>.enable` in `devenv.local.nix`). Copier still decides which languages are on.

## Community tools and presets

Tool files under `tools/` are Home Manager modules. They call `stdlib/tool.nix` with `install.kind` (`nix`, `catalog`, `hm-program`, `vscode-extension`, or `docker-image`) and `upgrade` (`flake`, `catalog`, or `self`). `stdlib.den.load` reads that tree.

Preset files under `presets/` call `mkPreset` from `stdlib/preset.nix` (`name`, `when`, `requires`, `tools`, `includes`). `mkPreset` is not on the flake `stdlib` attrset.
