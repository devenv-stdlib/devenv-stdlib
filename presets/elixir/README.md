# presets/elixir

Scaffold for devenv `languages.elixir` tool presets.

- Attrpaths: `elixir.*` (for example `elixir.lint.<tool>`)
- Category policy inherits when `languages.elixir.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
