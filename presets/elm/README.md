# presets/elm

Scaffold for devenv `languages.elm` tool presets.

- Attrpaths: `elm.*` (for example `elm.lint.<tool>`)
- Category policy inherits when `languages.elm.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
