# Den cascade diagrams (Phase 2 W2.5 — hand-maintained; den-diagram deferred).
# Source of truth for edges: modules/den/_cascades/*-cascade.nix. Read includes there first.

## Cursor (Phase 1)

```
cursor ──includes──► cursor-extensions
       └───────────► cursor-llm (mcp-stack)
```

## Terminal (Phase 2 W2.1)

```
terminal ──includes──► alacritty-quake  XOR  warp-quake
```

Default hub include is `alacritty-quake`. Switch provider by forcing the hub
`includes` to `[ warp-quake ]` and `terminal.provider = "warp"`.

## Languages (Phase 2 W2.2–W2.3)

```
python ──includes──► python-hooks
       ├───────────► python-ide-recs
       ├───────────► python-serena
       └───────────► python-debtmap
```

Same four-child shape for rust / go / javascript / typescript.
JS+TS share prettier, Serena `typescript` server, and the typescript IDE pack
(`project.javascriptOn`) — see `language-cascade.nix` `shared`.

Copier still only sets `languages.*.enable` in `devenv.local.nix`.

## Project IDEs (Phase 2 W2.4)

```
project-ides ──includes──► vscode-recs
             └───────────► cursor-sync-extensions
```

Language presets under `presets/<lang>/<category>/*.nix` supply project data via `stdlib.devenv.load`; shared `enterShell` hooks such as `cursor-sync-extensions` are wired in `stdlib/devenv.nix`. Aspects document composition.

## Developer home (Phase 4 cutover)

```
developer ──includes──► cursor
          ├───────────► terminal
          └───────────► home-cli   # remaining HM CLIs / IDEs
```

`home-switch` → flake `#developer` only. Language hubs use the custom
**`project`** class (not HM). See `modules/den/PROJECT-CLASS-SPIKE.md` and
`modules/den/CONTRIBUTING-ASPECTS.md`.

## Multi-OS (Phase 5)

```
fixture-nixos ──includes──► shell-tools   # nixos + darwin share one payload
fixture-darwin ──includes──► shell-tools
```

`shell-tools` is the first portable aspect with non-empty `nixos` **and**
`darwin` from one let-bound attrset. Host stubs: `modules/den/hosts.nix`
(`intoAttr = []`). Quake / GNOME terminal leaves stay HM-only — see
`modules/den/MULTI-OS.md`.
