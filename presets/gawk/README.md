# presets/gawk

Scaffold for devenv `languages.gawk` tool presets.

- Attrpaths: `gawk.*` (for example `gawk.lint.<tool>`)
- Category policy inherits when `languages.gawk.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
