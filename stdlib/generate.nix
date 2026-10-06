# Shared helpers for git-tracked generated files.
# Write mode updates $DEVENV_ROOT. --dry-run compares only (no writes).
# cmp treats newline-only differences as drift.
{ lib }:
let
  ensureTrailingNewline = text: if text == "" || lib.hasSuffix "\n" text then text else text + "\n";

  parseDryRun = ''
    dry_run=0
    if [ "''${DEVENV_STDLIB_DRY_RUN:-0}" = 1 ]; then
      dry_run=1
    fi
    for arg in "$@"; do
      case "$arg" in
        --dry-run) dry_run=1 ;;
        --) ;;
        -*)
          echo "unknown option: $arg" >&2
          exit 2
          ;;
      esac
    done
  '';

  # True when dest exists, is non-empty, and its last byte is a newline.
  destHasTrailingNewline = dest: ''
    [ -f ${dest} ] && [ -s ${dest} ] && [ "$(tail -c1 ${dest} | tr -d '\n' | wc -c)" -eq 0 ]
  '';
in
{
  inherit ensureTrailingNewline;

  # Copy storePath over $DEVENV_ROOT/relPath when bytes differ (incl. newline-only).
  mkSyncFileExec =
    {
      storePath,
      relPath,
    }:
    ''
      set -euo pipefail
      dest="$DEVENV_ROOT/${relPath}"
      src=${lib.escapeShellArg (toString storePath)}
      ${parseDryRun}
      if cmp -s "$src" "$dest" 2>/dev/null; then
        echo "up to date: ${relPath}"
        exit 0
      fi
      if [ "$dry_run" -eq 1 ]; then
        echo "stale: ${relPath}"
        exit 1
      fi
      mkdir -p "$(dirname "$dest")"
      tmp="$(mktemp)"
      cp "$src" "$tmp"
      chmod u+w "$tmp"
      mv "$tmp" "$dest"
      echo "wrote ${relPath}"
    '';

  # Keep on-disk contents; only add a trailing newline when it is missing.
  # Used for devenv.lock so a write never reverts pin updates from `devenv update`.
  mkEnsureTrailingNewlineExec =
    { relPath }:
    ''
      set -euo pipefail
      dest="$DEVENV_ROOT/${relPath}"
      ${parseDryRun}
      if ${destHasTrailingNewline "\"$dest\""}; then
        echo "up to date: ${relPath}"
        exit 0
      fi
      if [ "$dry_run" -eq 1 ]; then
        echo "stale: ${relPath}"
        exit 1
      fi
      if [ ! -f "$dest" ]; then
        echo "missing: ${relPath}" >&2
        exit 1
      fi
      tmp="$(mktemp)"
      cat "$dest" >"$tmp"
      printf '\n' >>"$tmp"
      chmod u+w "$tmp"
      mv "$tmp" "$dest"
      echo "wrote ${relPath}"
    '';
}
