# presets/ruby

Scaffold for devenv `languages.ruby` tool presets.

- Attrpaths: `ruby.*` (for example `ruby.lint.<tool>`)
- Category policy inherits when `languages.ruby.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
