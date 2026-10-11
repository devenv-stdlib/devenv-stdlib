# presets/ansible

Scaffold for devenv `languages.ansible` tool presets.

- Attrpaths: `ansible.*` (for example `ansible.lint.<tool>`)
- Category policy inherits when `languages.ansible.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
