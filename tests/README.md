# Tests

## Convention

| Location | What it covers |
| --- | --- |
| `tests/unit/stdlib/` | stdlib API, loaders, category engine, packaging |
| `tests/unit/aspects/` | Den aspect cascades / goldens |
| `tests/unit/*.nix` | Other cross-cutting helpers (versions, hooks, matrices, catalog, …) |
| `tools/<…>/<name>/tests/{unit,integration}/` | That tool only |
| `presets/<…>/<name>/tests/{unit,integration}/` | That preset only |
| `tests/integration/` | Cross-cutting nixosTest / workflow fixtures |

Owner suites are discovered additively: any `tools/**/tests/unit/default.nix` or `presets/**/tests/unit/default.nix` is a separate nix-unit invocation. Integration uses the same pattern under `tests/integration/default.nix`.

`stdlib.discover` and devenv preset collection skip `tests/` directories so colocated suites are not loaded as tools or presets.

Shared loaders live in `tests/lib/` (`suite.nix`, `discover-suites.nix`, `harness.nix`, `preset-eval.nix`).
