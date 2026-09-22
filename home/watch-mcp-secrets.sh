#!/usr/bin/env bash
# Re-upsert Cursor Brave/Firecrawl MCP when SecretSpec or .env keys change.
# Long-running: inotify on .env plus a poll (keyring has no file to watch).
# shellcheck disable=SC1090

MCP_SECRETS_POLL_SEC=${MCP_SECRETS_POLL_SEC:-30}

mcp_secrets_host_dir() {
  printf '%s' "${MCP_SECRETS_HOST_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/devenv4monorepo}"
}

mcp_secrets_fingerprint_file() {
  printf '%s' "${MCP_SECRETS_FINGERPRINT:-$(mcp_secrets_host_dir)/secrets.fingerprint}"
}

mcp_secrets_devenv_root_file() {
  printf '%s' "${MCP_SECRETS_DEVENV_ROOT_FILE:-$(mcp_secrets_host_dir)/devenv-root}"
}

mcp_secrets_wrappers_file() {
  printf '%s' "${MCP_SECRETS_WRAPPERS:-$(mcp_secrets_host_dir)/mcp-wrappers.env}"
}

mcp_secrets_mcp_json() {
  printf '%s' "${CURSOR_MCP_JSON:-$HOME/.cursor/mcp.json}"
}

mcp_secrets_fingerprint() {
  # Hash values only; never write secrets to the fingerprint file.
  printf 'brave=%s\nfirecrawl=%s\n' \
    "${BRAVE_API_KEY-}" "${FIRECRAWL_API_KEY-}" |
    sha256sum | awk '{print $1}'
}

# Store-path activation passes sibling scripts as env overrides.
mcp_secrets_source_home() {
  local name=$1
  local override=$2
  local here path
  if [[ -n $override && -f $override ]]; then
    path=$override
  else
    here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    path=$here/$name
  fi
  # shellcheck disable=SC1090
  . "$path"
}

mcp_secrets_sync() {
  local root=$1
  local hash prev wrappers

  mcp_secrets_source_home load-secrets.sh "${MCP_SECRETS_LOAD_SECRETS_SH-}"
  mcp_secrets_source_home ides/merge-cursor-llm.sh "${MCP_SECRETS_MERGE_CURSOR_SH-}"
  home_load_secrets "$root"

  hash=$(mcp_secrets_fingerprint)
  fingerprint_file=$(mcp_secrets_fingerprint_file)
  prev=$(cat "$fingerprint_file" 2>/dev/null || true)
  if [[ $hash == "$prev" ]]; then
    return 0
  fi

  wrappers=$(mcp_secrets_wrappers_file)
  if [[ -f $wrappers ]]; then
    # shellcheck disable=SC1090
    . "$wrappers"
    if ! merge_cursor_mcp_secrets "$(mcp_secrets_mcp_json)" "$BRAVE_MCP" "$FIRECRAWL_MCP"; then
      return 1
    fi
  fi

  mkdir -p "$(dirname "$fingerprint_file")"
  umask 077
  printf '%s\n' "$hash" >"$fingerprint_file"
}

mcp_secrets_watch() {
  local root poll envfile devenv_root_file
  devenv_root_file=$(mcp_secrets_devenv_root_file)
  while [[ ! -s $devenv_root_file ]]; do
    sleep 5
  done
  root=$(tr -d '\n' <"$devenv_root_file")
  poll=$MCP_SECRETS_POLL_SEC
  envfile="$root/.env"

  mcp_secrets_sync "$root" || true

  if command -v inotifywait >/dev/null 2>&1 && [[ -f $envfile ]]; then
    inotifywait -m -q -e close_write,moved_to "$envfile" 2>/dev/null |
      while read -r _; do
        sleep 1
        mcp_secrets_sync "$root" || true
      done &
  fi

  while true; do
    sleep "$poll"
    mcp_secrets_sync "$root" || true
  done
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  set -euo pipefail
  cmd=${1:-watch}
  case $cmd in
    sync) mcp_secrets_sync "${2:-${DEVENV_ROOT:-.}}" ;;
    watch) mcp_secrets_watch ;;
    *)
      echo "usage: $0 sync [root] | watch" >&2
      exit 2
      ;;
  esac
fi
