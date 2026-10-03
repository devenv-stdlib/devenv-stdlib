# presets/shell

Scaffold for devenv `languages.shell` tool presets.

- Attrpaths: `shell.*` (for example `shell.lint.<tool>`)
- Category policy inherits when `languages.shell.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
