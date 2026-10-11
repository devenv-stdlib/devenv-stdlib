# presets/cue

Scaffold for devenv `languages.cue` tool presets.

- Attrpaths: `cue.*` (for example `cue.lint.<tool>`)
- Category policy inherits when `languages.cue.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
