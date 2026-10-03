# presets/erlang

Scaffold for devenv `languages.erlang` tool presets.

- Attrpaths: `erlang.*` (for example `erlang.lint.<tool>`)
- Category policy inherits when `languages.erlang.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
