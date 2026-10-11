# presets/haskell

Scaffold for devenv `languages.haskell` tool presets.

- Attrpaths: `haskell.*` (for example `haskell.lint.<tool>`)
- Category policy inherits when `languages.haskell.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
