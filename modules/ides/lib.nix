{
  pkgs,
  lib,
  config,
}:
let
  ext = import ../../home/vscode-ext-lib.nix { inherit pkgs; };
  project = import ../lib/project.nix { inherit lib; };

  languages = config.languages or { };
  langOn = name: project.langOn languages name;
  typescriptOn = project.javascriptOn languages;

  selected =
    lib.optionals (langOn "rust") ext.rust
    ++ lib.optionals (langOn "go") ext.go
    ++ lib.optionals (langOn "python") ext.python
    ++ lib.optionals typescriptOn ext.typescript;

  unwantedRecommendations = project.vscodeUnwanted languages;

  recommendations = project.vscodeAlwaysRecommend ++ map ext.id selected;

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

  rustEdition = config.supported.rust.edition or null;

  rustSettings = {
    "[rust]" = {
      "editor.defaultFormatter" = "rust-lang.rust-analyzer";
      "editor.formatOnSave" = true;
    };
  }
  // lib.optionalAttrs (rustEdition != null) {
    "rust-analyzer.rustfmt.extraArgs" = [
      "--edition"
      rustEdition
    ];
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

  manifest = pkgs.writeText "ide-ext-manifest" (
    lib.concatMapStringsSep "\n" (e: "${ext.id e}|${ext.root e}") selected
  );
in
{
  inherit
    ext
    selected
    recommendations
    unwantedRecommendations
    settings
    settingsJson
    manifest
    ;

  # extensionsDir is expanded by the shell ($HOME/...). Only adds missing
  # symlinks; never deletes user-installed extensions.
  mkSyncScript =
    {
      extensionsDir,
      logPrefix ? "ides",
    }:
    ''
      set -euo pipefail
      dest_root="${extensionsDir}"
      mkdir -p "$dest_root" "$DEVENV_ROOT/.vscode"

      if [ -s ${lib.escapeShellArg manifest} ]; then
        while IFS='|' read -r id src; do
          [ -n "$id" ] || continue
          dest="$dest_root/$id"
          if [ ! -e "$dest" ]; then
            ln -s "$src" "$dest"
            echo "${logPrefix}: installed $id"
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
        echo "${logPrefix}: wrote .vscode/settings.json for this project's languages"
      fi
    '';
}
