# presets/texlive

Scaffold for devenv `languages.texlive` tool presets.

- Attrpaths: `texlive.*` (for example `texlive.lint.<tool>`)
- Category policy inherits when `languages.texlive.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
