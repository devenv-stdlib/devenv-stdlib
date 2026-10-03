# presets/java

Scaffold for devenv `languages.java` tool presets.

- Attrpaths: `java.*` (for example `java.lint.<tool>`)
- Category policy inherits when `languages.java.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
