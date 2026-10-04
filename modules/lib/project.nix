# Implementation lives here. tests/integration/default.nix copies this path
# into the Nix store as a single file, and that copy is evaluated on its own.
# stdlib/project.nix re-exports this file.
{ lib }:
# Pure language enable → hooks / serena / vscode / debtmap helpers.
# Cascade fan-out ("what does python enable?") lives in
# modules/den/_cascades/language-cascade.nix and den.aspects.* includes — not
# in this file. Enable flags still come from Copier / languages.*.enable.
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
      debtmap = debtmapLanguages languages != [ ];
    };

  # Languages written to generated .debtmap.toml (https://github.com/iepathos/debtmap).
  # Solidity is unsupported here; this devenv has no languages.solidity.
  debtmapLanguages =
    languages:
    lib.optionals (langOn languages "rust") [ "rust" ]
    ++ lib.optionals (langOn languages "python") [ "python" ]
    ++ lib.optionals (langOn languages "javascript") [ "javascript" ]
    ++ lib.optionals (langOn languages "typescript") [ "typescript" ]
    ++ lib.optionals (langOn languages "go") [ "go" ];

  debtmapFiles =
    languages:
    let
      exts = {
        rust = "rs";
        python = "py";
        javascript = "js|jsx|mjs|cjs";
        typescript = "ts|tsx";
        go = "go";
      };
      langs = debtmapLanguages languages;
    in
    if langs == [ ] then "" else "\\.(${lib.concatStringsSep "|" (map (name: exts.${name}) langs)})$";

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
    "check-merge-conflicts"
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

  vscodeAlwaysRecommend = [
    "datakurre.devenv"
    "jnoortheen.nix-ide"
    "coderabbit.coderabbit-vscode"
  ];

  # Ids used as unwantedRecommendations when a pack is off. Keep in sync with
  # modules/ides (golang.Go matches the existing Cursor/VS Code id).
  vscodeLanguageIds = {
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

  vscodeUnwanted =
    languages:
    lib.optionals (!langOn languages "rust") vscodeLanguageIds.rust
    ++ lib.optionals (!langOn languages "go") vscodeLanguageIds.go
    ++ lib.optionals (!langOn languages "python") vscodeLanguageIds.python
    ++ lib.optionals (!javascriptOn languages) vscodeLanguageIds.typescript;

  vscodeRecommendations =
    languages:
    vscodeAlwaysRecommend
    ++ lib.optionals (langOn languages "rust") vscodeLanguageIds.rust
    ++ lib.optionals (langOn languages "go") vscodeLanguageIds.go
    ++ lib.optionals (langOn languages "python") vscodeLanguageIds.python
    ++ lib.optionals (javascriptOn languages) vscodeLanguageIds.typescript;

  # Always-on Serena language_servers id for this template (Nix).
  serenaAlwaysLanguageServers = [ "nix" ];

  # Ids written to generated .serena/project.yml. javascript and
  # typescript both use Serena's typescript server (once). Deno is a
  # JS runtime here, not a separate Cursor language pack.
  serenaLanguageServers =
    languages:
    serenaAlwaysLanguageServers
    ++ lib.optionals (langOn languages "rust") [ "rust" ]
    ++ lib.optionals (langOn languages "go") [ "go" ]
    ++ lib.optionals (langOn languages "python") [ "python" ]
    ++ lib.optionals (javascriptOn languages) [ "typescript" ];
}
