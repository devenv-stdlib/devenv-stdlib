# presets/python

Scaffold for devenv `languages.python` tool presets.

- Attrpaths: `python.*` (for example `python.lint.<tool>`)
- Category policy inherits when `languages.python.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
