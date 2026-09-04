{
  pkgs,
  lib,
  config,
  ...
}:
let
  ext = import ../home/vscode-ext-lib.nix { inherit pkgs; };

  langOn = name: (config.languages.${name} or { }).enable or false;

  typescriptOn = langOn "javascript" || langOn "typescript";

  selected =
    lib.optionals (langOn "rust") ext.rust
    ++ lib.optionals (langOn "go") ext.go
    ++ lib.optionals (langOn "python") ext.python
    ++ lib.optionals typescriptOn ext.typescript;

  # Hardcoded ids so disabled packs are not evaluated (Pylance is unfree).
  unwantedRecommendations =
    lib.optionals (!langOn "rust") [
      "rust-lang.rust-analyzer"
      "vadimcn.vscode-lldb"
      "fill-labs.dependi"
    ]
    ++ lib.optionals (!langOn "go") [ "golang.Go" ]
    ++ lib.optionals (!langOn "python") [
      "ms-python.python"
      "ms-python.vscode-pylance"
      "ms-python.debugpy"
      "charliermarsh.ruff"
    ]
    ++ lib.optionals (!typescriptOn) [
      "dbaeumer.vscode-eslint"
      "bradlc.vscode-tailwindcss"
      "yoavbls.pretty-ts-errors"
      "formulahendry.auto-rename-tag"
    ];

  # devenv + nix-ide are always relevant in this repo; language ids follow
  # languages.*.enable so Cursor only recommends what this project uses.
  recommendations = [
    "datakurre.devenv"
    "jnoortheen.nix-ide"
  ]
  ++ map ext.id selected;

  nixSettings = {
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = [
      "devenv"
      "lsp"
    ];
    "[nix]" = {
      "editor.defaultFormatter" = "jnoortheen.nix-ide";
      "editor.insertSpaces" = true;
      "editor.tabSize" = 2;
    };
  };

  rustSettings = {
    "[rust]" = {
      "editor.defaultFormatter" = "rust-lang.rust-analyzer";
      "editor.formatOnSave" = true;
    };
  };

  goSettings = {
    "go.useLanguageServer" = true;
    "[go]" = {
      "editor.defaultFormatter" = "golang.go";
      "editor.formatOnSave" = true;
    };
  };

  pythonSettings = {
    "python.languageServer" = "Pylance";
    "[python]" = {
      "editor.defaultFormatter" = "charliermarsh.ruff";
      "editor.formatOnSave" = true;
      "editor.codeActionsOnSave" = {
        "source.fixAll.ruff" = "explicit";
        "source.organizeImports.ruff" = "explicit";
      };
    };
  };

  typescriptSettings = {
    "eslint.validate" = [
      "javascript"
      "javascriptreact"
      "typescript"
      "typescriptreact"
    ];
    "[typescript]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
      "editor.formatOnSave" = true;
    };
    "[typescriptreact]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
      "editor.formatOnSave" = true;
    };
    "[javascript]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
      "editor.formatOnSave" = true;
    };
    "[javascriptreact]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
      "editor.formatOnSave" = true;
    };
  };

  settings =
    nixSettings
    // lib.optionalAttrs (langOn "rust") rustSettings
    // lib.optionalAttrs (langOn "go") goSettings
    // lib.optionalAttrs (langOn "python") pythonSettings
    // lib.optionalAttrs typescriptOn typescriptSettings;

  settingsJson = pkgs.writeText "settings.json" (builtins.toJSON settings);

  manifest = pkgs.writeText "cursor-ext-manifest" (
    lib.concatMapStringsSep "\n" (e: "${ext.id e}|${ext.root e}") selected
  );
in
{
  # Regenerated on devenv:files from languages.*. Do not edit by hand.
  files.".vscode/extensions.json".json = {
    inherit recommendations;
    inherit unwantedRecommendations;
  };

  scripts.cursor-sync-extensions.exec = ''
    set -euo pipefail
    dest_root="''${HOME:?}/.cursor/extensions"
    mkdir -p "$dest_root" "$DEVENV_ROOT/.vscode"

    if [ -s ${lib.escapeShellArg manifest} ]; then
      while IFS='|' read -r id src; do
        [ -n "$id" ] || continue
        dest="$dest_root/$id"
        if [ ! -e "$dest" ]; then
          ln -s "$src" "$dest"
          echo "cursor: installed $id"
        fi
      done < ${lib.escapeShellArg manifest}
    fi

    write_json() {
      src="$1"
      dest="$2"
      tmp="$(mktemp)"
      jq . "$src" >"$tmp"
      if ! cmp -s "$tmp" "$dest" 2>/dev/null; then
        mv "$tmp" "$dest"
        return 0
      fi
      rm -f "$tmp"
      return 1
    }

    if write_json ${lib.escapeShellArg settingsJson} "$DEVENV_ROOT/.vscode/settings.json"; then
      echo "cursor: wrote .vscode/settings.json for this project's languages"
    fi
  '';

  enterShell = ''
    cursor-sync-extensions
  '';
}
