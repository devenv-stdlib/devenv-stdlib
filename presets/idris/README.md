# presets/idris

Scaffold for devenv `languages.idris` tool presets.

- Attrpaths: `idris.*` (for example `idris.lint.<tool>`)
- Category policy inherits when `languages.idris.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
