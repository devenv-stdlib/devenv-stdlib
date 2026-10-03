# Example preset compositions

Framework presets are **tool-sized** (`presets/lang/<lang>/<tool>.nix`). Larger stacks — “give me a full Python setup” — are a **user or community opinion**, not a framework megapreset named Python.

This directory documents compositions. Files here are **not** loaded by `modules/devenv.nix`. Copy the pattern into your own repository (or extend `presets/omer.nix` in the template) with `mkPreset` `includes` / by enabling the named tool presets you want.

See `python.nix` for a worked example.
