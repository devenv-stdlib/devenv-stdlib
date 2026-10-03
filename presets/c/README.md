# presets/c

Scaffold for devenv `languages.c` tool presets.

- Attrpaths: `c.*` (for example `c.lint.<tool>`)
- Category policy inherits when `languages.c.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
