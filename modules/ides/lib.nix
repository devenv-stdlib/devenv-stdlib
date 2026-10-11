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
    }:
    let
      manifest = pkgs.writeText "ide-ext-manifest" (
        lib.concatMapStringsSep "\n" (e: "${ext.id e}|${ext.root e}") selected
      );
    in
    ''
      set -euo pipefail
      dest_root="${extensionsDir}"
      mkdir -p "$dest_root"

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
    '';
}
