# Example preset compositions

Framework presets are **tool-sized** and namespaced by category (`presets/python/lint/ruff.nix` → `python.lint.ruff`). Larger stacks — “give me a full Python setup” — belong in the consumer repo or community compositions.

This directory documents compositions. Files here are **not** loaded by `modules/devenv.nix`. Copy the pattern into your own repository (or extend `presets/omer.nix` in the template) with `mkPreset` `includes` via attrpath refs:

```nix
includes = with presets; [
  python.lint.ruff
  python.type.pyright
];
```

See `python.nix` for a worked example.
