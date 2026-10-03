# presets/crystal

Scaffold for devenv `languages.crystal` tool presets.

- Attrpaths: `crystal.*` (for example `crystal.lint.<tool>`)
- Category policy inherits when `languages.crystal.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
