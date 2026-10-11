# presets/purescript

Scaffold for devenv `languages.purescript` tool presets.

- Attrpaths: `purescript.*` (for example `purescript.lint.<tool>`)
- Category policy inherits when `languages.purescript.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
