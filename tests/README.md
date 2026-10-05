# Tests

## Convention

| Location | What it covers |
| --- | --- |
| `tests/unit/stdlib/` | stdlib API via **mock** tools/presets (`tests/fixtures/mock-framework/`) |
| `tests/unit/aspects/` | Den aspect cascades / goldens |
| `tests/unit/*.nix` | Other cross-cutting helpers (versions, hooks, matrices, catalog, …) |
| `tools/<…>/<name>/tests/{unit,integration}/` | That **real** tool only |
| `presets/<…>/<name>/tests/{unit,integration}/` | That **real** preset only |
| `tests/integration/` | Cross-cutting nixosTest / workflow fixtures |

The main suite must not load production `tools/` or `presets/` for API coverage. Use `tests/lib/mock-framework.nix` + `tests/fixtures/mock-framework/{tools,presets}/` instead. Real leaf behavior stays in owner suites.

Owner suites are discovered additively: any `tools/**/tests/unit/default.nix` or `presets/**/tests/unit/default.nix` is a separate nix-unit invocation. Integration uses the same pattern under `tests/integration/default.nix`.

`stdlib.discover` and devenv preset collection skip `tests/` directories so colocated suites are not loaded as tools or presets.

Shared loaders live in `tests/lib/` (`suite.nix`, `discover-suites.nix`, `harness.nix`, `preset-eval.nix`, `mock-framework.nix`).
