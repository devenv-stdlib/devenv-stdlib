#!/usr/bin/env bash
# Install AppArmor profiles so Cursor Agent terminal sandbox works on Ubuntu
# with kernel.apparmor_restrict_unprivileged_userns=1 (default on 24.04+).
# Requires root. Idempotent. Safe to re-run after Cursor / nixpkgs upgrades.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROFILE_SRC=$SCRIPT_DIR/apparmor.d/cursor-sandbox-nix
PROFILE_DST=/etc/apparmor.d/cursor-sandbox-nix

fail() {
  printf 'cursor-agent-sandbox: %s\n' "$*" >&2
  exit 1
}

need_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    fail "must run as root (setup.sh invokes this with sudo)"
  fi
}

have_apparmor() {
  [[ -d /sys/module/apparmor ]] || return 1
  command -v apparmor_parser >/dev/null 2>&1 || return 1
  return 0
}

install_profile() {
  install -d -m 0755 /etc/apparmor.d /etc/apparmor.d/local
  install -m 0644 "$PROFILE_SRC" "$PROFILE_DST"
  # Validate then load (replace if already loaded).
  apparmor_parser -r "$PROFILE_DST" || fail "apparmor_parser failed for $PROFILE_DST"
}

find_cursorsandbox() {
  local p
  # Prefer the running Nix Cursor helper when present.
  for p in /nix/store/*-cursor-*/lib/cursor/resources/app/resources/helpers/cursorsandbox; do
    if [[ -x $p ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  for p in \
    "$HOME/.config/Cursor/User/globalStorage/anysphere.cursor-agent-worker/agent-cli/.local/share/cursor-agent/versions/"*/cursorsandbox \
    "$HOME/.local/share/cursor-agent/versions/"*/cursorsandbox; do
    if [[ -x $p ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

preflight() {
  local cs policy
  cs=$(find_cursorsandbox) || {
    printf 'cursor-agent-sandbox: no cursorsandbox binary found yet; profiles installed, skip preflight\n' >&2
    return 0
  }
  policy=$(mktemp)
  cat >"$policy" <<EOF
{"sandbox":{"type":"workspace_readwrite","cwd":"${HOME:-/tmp}"},"network":{"mode":"deny"}}
EOF
  if "$cs" --policy "$policy" --preflight-only -- /bin/true; then
    rm -f "$policy"
    printf 'cursor-agent-sandbox: preflight ok (%s)\n' "$cs"
    return 0
  fi
  local rc=$?
  rm -f "$policy"
  printf 'cursor-agent-sandbox: preflight failed (exit %s) for %s\n' "$rc" "$cs" >&2
  return "$rc"
}

main() {
  need_root
  [[ -f $PROFILE_SRC ]] || fail "missing profile source $PROFILE_SRC"

  if ! have_apparmor; then
    printf 'cursor-agent-sandbox: AppArmor not available; skipping\n' >&2
    return 0
  fi

  install_profile
  # Preflight as the invoking user when SUDO_USER is set (sandbox uses $HOME).
  if [[ -n ${SUDO_USER:-} && ${SUDO_USER} != root ]]; then
    if command -v runuser >/dev/null 2>&1; then
      runuser -u "$SUDO_USER" -- env HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)" \
        bash -c "$(declare -f find_cursorsandbox preflight); preflight" || true
    else
      preflight || true
    fi
  else
    preflight || true
  fi
}

main "$@"
