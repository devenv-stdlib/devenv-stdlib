# presets/racket

Scaffold for devenv `languages.racket` tool presets.

- Attrpaths: `racket.*` (for example `racket.lint.<tool>`)
- Category policy inherits when `languages.racket.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
