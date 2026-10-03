# presets/clojure

Scaffold for devenv `languages.clojure` tool presets.

- Attrpaths: `clojure.*` (for example `clojure.lint.<tool>`)
- Category policy inherits when `languages.clojure.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
