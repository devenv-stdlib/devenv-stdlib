# presets/lean4

Scaffold for devenv `languages.lean4` tool presets.

- Attrpaths: `lean4.*` (for example `lean4.lint.<tool>`)
- Category policy inherits when `languages.lean4.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
