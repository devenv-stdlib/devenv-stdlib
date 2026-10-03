# presets/perl

Scaffold for devenv `languages.perl` tool presets.

- Attrpaths: `perl.*` (for example `perl.lint.<tool>`)
- Category policy inherits when `languages.perl.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
