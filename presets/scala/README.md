# presets/scala

Scaffold for devenv `languages.scala` tool presets.

- Attrpaths: `scala.*` (for example `scala.lint.<tool>`)
- Category policy inherits when `languages.scala.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
