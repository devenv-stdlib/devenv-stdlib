# presets/php

Scaffold for devenv `languages.php` tool presets.

- Attrpaths: `php.*` (for example `php.lint.<tool>`)
- Category policy inherits when `languages.php.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
