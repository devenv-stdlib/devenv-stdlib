# presets/pkl

Scaffold for devenv `languages.pkl` tool presets.

- Attrpaths: `pkl.*` (for example `pkl.lint.<tool>`)
- Category policy inherits when `languages.pkl.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
