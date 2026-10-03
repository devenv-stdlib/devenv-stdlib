# presets/lobster

Scaffold for devenv `languages.lobster` tool presets.

- Attrpaths: `lobster.*` (for example `lobster.lint.<tool>`)
- Category policy inherits when `languages.lobster.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
