# presets/unison

Scaffold for devenv `languages.unison` tool presets.

- Attrpaths: `unison.*` (for example `unison.lint.<tool>`)
- Category policy inherits when `languages.unison.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
