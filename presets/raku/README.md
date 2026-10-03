# presets/raku

Scaffold for devenv `languages.raku` tool presets.

- Attrpaths: `raku.*` (for example `raku.lint.<tool>`)
- Category policy inherits when `languages.raku.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
