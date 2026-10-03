# Sync script for Cursor and VS Code extension roots.
# Language packs are chosen by presets/<lang>/ide.nix; this file only
# materializes the symlink script.
{
  pkgs,
  lib,
}:
let
  ext = import ../../home/ides/ext-lib.nix { inherit pkgs; };
in
{
  inherit ext;

  mkSyncScript =
    {
      extensionsDir,
      logPrefix ? "ides",
      selected,
      settings,
    }:
    let
      settingsJson = pkgs.writeText "settings.json" (builtins.toJSON settings);
      manifest = pkgs.writeText "ide-ext-manifest" (
        lib.concatMapStringsSep "\n" (e: "${ext.id e}|${ext.root e}") selected
      );
    in
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
