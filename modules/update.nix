# `update` is our devenv script. It does not wrap the devenv CLI
# (`devenv update` stays lockfile-only).
_: {
  scripts.update.exec = ''
    set -euo pipefail
    exec bash "$DEVENV_ROOT/modules/update.sh" "$@"
  '';
}
