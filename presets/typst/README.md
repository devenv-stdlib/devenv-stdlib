# presets/typst

Scaffold for devenv `languages.typst` tool presets.

- Attrpaths: `typst.*` (for example `typst.lint.<tool>`)
- Category policy inherits when `languages.typst.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
