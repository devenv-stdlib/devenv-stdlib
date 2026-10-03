# presets/standardml

Scaffold for devenv `languages.standardml` tool presets.

- Attrpaths: `standardml.*` (for example `standardml.lint.<tool>`)
- Category policy inherits when `languages.standardml.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
