{ lib }:
rec {
  langOn = languages: name: (languages.${name} or { }).enable or false;

  javascriptOn = languages: langOn languages "javascript" || langOn languages "typescript";

  languageHooks =
    {
      languages ? { },
      pythonTypeChecker ? "pyright",
    }:
    let
      on = langOn languages;
      pythonOn = on "python";
      tsOn = javascriptOn languages;
    in
    {
      rustfmt = on "rust";
      clippy = on "rust";
      gofmt = on "go";
      golangci-lint = on "go";
      ruff = pythonOn;
      ruff-format = pythonOn;
      check-python = pythonOn;
      python-debug-statements = pythonOn;
      sort-requirements-txt = pythonOn;
      pyright = pythonOn && pythonTypeChecker == "pyright";
      ty = pythonOn && pythonTypeChecker == "ty";
      prettier = tsOn;
    };

  alwaysOnHookNames = [
    "nixfmt"
    "statix"
    "deadnix"
    "shellcheck"
    "commitlint"
    "typos"
    "proselint"
    "lychee"
    "actionlint"
    "yamlfmt"
    "check-json"
    "trim-trailing-whitespace"
    "end-of-file-fixer"
    "check-added-large-files"
    "check-case-conflicts"
    "gitleaks"
  ];

  typescriptBundlers = [
    "vite"
    "turbopack"
    "rspack"
    "tsup"
    "tsdown"
  ];

  typescriptBundlerMissing = typescriptEnable: bundler: typescriptEnable && bundler == null;

  cursorAlwaysRecommend = [
    "datakurre.devenv"
    "jnoortheen.nix-ide"
  ];

  # Ids used as unwantedRecommendations when a pack is off. Keep in sync with
  # cursor-languages.nix (golang.Go matches the existing Cursor id).
  cursorLanguageIds = {
    rust = [
      "rust-lang.rust-analyzer"
      "vadimcn.vscode-lldb"
      "fill-labs.dependi"
    ];
    go = [ "golang.Go" ];
    python = [
      "ms-python.python"
      "ms-python.vscode-pylance"
      "ms-python.debugpy"
      "charliermarsh.ruff"
    ];
    typescript = [
      "dbaeumer.vscode-eslint"
      "bradlc.vscode-tailwindcss"
      "yoavbls.pretty-ts-errors"
      "formulahendry.auto-rename-tag"
    ];
  };

  cursorUnwanted =
    languages:
    lib.optionals (!langOn languages "rust") cursorLanguageIds.rust
    ++ lib.optionals (!langOn languages "go") cursorLanguageIds.go
    ++ lib.optionals (!langOn languages "python") cursorLanguageIds.python
    ++ lib.optionals (!javascriptOn languages) cursorLanguageIds.typescript;

  cursorRecommendations =
    languages:
    cursorAlwaysRecommend
    ++ lib.optionals (langOn languages "rust") cursorLanguageIds.rust
    ++ lib.optionals (langOn languages "go") cursorLanguageIds.go
    ++ lib.optionals (langOn languages "python") cursorLanguageIds.python
    ++ lib.optionals (javascriptOn languages) cursorLanguageIds.typescript;
}
