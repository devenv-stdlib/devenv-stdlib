# presets/gleam

Scaffold for devenv `languages.gleam` tool presets.

- Attrpaths: `gleam.*` (for example `gleam.lint.<tool>`)
- Category policy inherits when `languages.gleam.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
