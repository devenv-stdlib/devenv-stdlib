#!/usr/bin/env bash
# Keep Ubuntu's ~/.bashrc and append a ~/.bashrc.d hook. Home Manager used to
# replace ~/.bashrc; a distro upgrade then dropped Nix and Starship.
# Sourced by tests; executed from home.activation.

MARKER="# devenv4monorepo: .bashrc.d"

is_nix_store_link() {
  local path=$1
  [[ -L $path ]] || return 1
  local resolved
  resolved=$(readlink -f "$path")
  [[ $resolved == /nix/store/* ]]
}

has_bashrc_d_hook() {
  grep -qF "$MARKER" "$1"
}

ensure_bashrc_d() {
  local bashrc=$1
  local skel=${2:-/etc/skel/.bashrc}

  if is_nix_store_link "$bashrc"; then
    rm -f "$bashrc"
  fi

  if [[ ! -e $bashrc ]]; then
    if [[ -f $skel ]]; then
      cp "$skel" "$bashrc"
    else
      cat >"$bashrc" <<'EOF'
# ~/.bashrc
case $- in
    *i*) ;;
      *) return;;
esac
EOF
    fi
  fi

  if has_bashrc_d_hook "$bashrc"; then
    return 0
  fi

  cat >>"$bashrc" <<EOF

$MARKER
if [ -d "\$HOME/.bashrc.d" ]; then
  for _rc in "\$HOME/.bashrc.d/"*.sh; do
    [ -f "\$_rc" ] && . "\$_rc"
  done
  unset _rc
fi
EOF
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  set -euo pipefail
  ensure_bashrc_d "$@"
fi
