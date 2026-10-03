# presets/typescript

Scaffold for devenv `languages.typescript` tool presets.

- Attrpaths: `typescript.*` (for example `typescript.lint.<tool>`)
- Category policy inherits when `languages.typescript.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
