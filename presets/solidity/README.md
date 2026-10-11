# presets/solidity

Scaffold for devenv `languages.solidity` tool presets.

- Attrpaths: `solidity.*` (for example `solidity.lint.<tool>`)
- Category policy inherits when `languages.solidity.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
