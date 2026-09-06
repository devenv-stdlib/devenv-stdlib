#!/usr/bin/env bash
# Re-upsert 9Router and Cursor Brave/Firecrawl when SecretSpec or .env keys change.
# Long-running: inotify on .env plus a poll (keyring has no file to watch).
# shellcheck disable=SC1090

NINEROUTER_SECRETS_POLL_SEC=${NINEROUTER_SECRETS_POLL_SEC:-30}

nine_router_host_dir() {
  printf '%s' "${NINEROUTER_HOST_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/9router}"
}

nine_router_fingerprint_file() {
  printf '%s' "${NINEROUTER_SECRETS_FINGERPRINT:-$(nine_router_host_dir)/secrets.fingerprint}"
}

nine_router_devenv_root_file() {
  printf '%s' "${NINEROUTER_DEVENV_ROOT_FILE:-$(nine_router_host_dir)/devenv-root}"
}

nine_router_mcp_wrappers_file() {
  printf '%s' "${NINEROUTER_MCP_WRAPPERS:-$(nine_router_host_dir)/mcp-wrappers.env}"
}

nine_router_mcp_json() {
  printf '%s' "${CURSOR_MCP_JSON:-$HOME/.cursor/mcp.json}"
}

nine_router_secrets_fingerprint() {
  # Hash values only; never write secrets to the fingerprint file.
  printf 'brave=%s\nfirecrawl=%s\npassword=%s\n' \
    "${BRAVE_API_KEY-}" "${FIRECRAWL_API_KEY-}" "${INITIAL_PASSWORD-}" |
    sha256sum | awk '{print $1}'
}

nine_router_sync_secrets() {
  local root=$1
  local here hash prev wrappers

  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  # shellcheck disable=SC1091
  . "$here/load-secrets.sh"
  # shellcheck disable=SC1091
  . "$here/configure-9router.sh"
  # shellcheck disable=SC1091
  . "$here/merge-cursor-llm.sh"
  home_load_secrets "$root"

  hash=$(nine_router_secrets_fingerprint)
  fingerprint_file=$(nine_router_fingerprint_file)
  prev=$(cat "$fingerprint_file" 2>/dev/null || true)
  if [[ $hash == "$prev" ]]; then
    return 0
  fi

  wrappers=$(nine_router_mcp_wrappers_file)
  if [[ -f $wrappers ]]; then
    # Store paths from the last home-switch. Secrets change more often.
    # shellcheck disable=SC1090
    . "$wrappers"
    if ! merge_cursor_mcp_secrets "$(nine_router_mcp_json)" "$BRAVE_MCP" "$FIRECRAWL_MCP"; then
      return 1
    fi
  fi

  if [[ -n ${NINEROUTER_SYNC_HOOK:-} ]]; then
    # Tests replace the live POST. Production leaves this unset.
    if ! ${NINEROUTER_SYNC_HOOK}; then
      return 1
    fi
  elif ! configure_9router http://127.0.0.1:20128 http://host.docker.internal:8787; then
    return 1
  fi
  mkdir -p "$(dirname "$fingerprint_file")"
  umask 077
  printf '%s\n' "$hash" >"$fingerprint_file"
}

nine_router_watch_secrets() {
  local root poll envfile devenv_root_file
  devenv_root_file=$(nine_router_devenv_root_file)
  while [[ ! -s $devenv_root_file ]]; do
    sleep 5
  done
  root=$(tr -d '\n' <"$devenv_root_file")
  poll=$NINEROUTER_SECRETS_POLL_SEC
  envfile="$root/.env"

  nine_router_sync_secrets "$root" || true

  if command -v inotifywait >/dev/null 2>&1 && [[ -f $envfile ]]; then
    inotifywait -m -q -e close_write,moved_to "$envfile" 2>/dev/null |
      while read -r _; do
        sleep 1
        nine_router_sync_secrets "$root" || true
      done &
  fi

  while true; do
    sleep "$poll"
    nine_router_sync_secrets "$root" || true
  done
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  set -euo pipefail
  cmd=${1:-watch}
  case $cmd in
    sync) nine_router_sync_secrets "${2:-${DEVENV_ROOT:-.}}" ;;
    watch) nine_router_watch_secrets ;;
    *)
      echo "usage: $0 sync [root] | watch" >&2
      exit 2
      ;;
  esac
fi
