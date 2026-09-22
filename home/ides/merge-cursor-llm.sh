#!/usr/bin/env bash
# Merge Cursor mcp.json without replacing user entries.
# MCP upsert core lives in mcp/merge-lib.sh (harness-agnostic).
# Sourced by tests; executed from home.activation.
# shellcheck disable=SC1091,SC2016

_MERGE_CURSOR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=mcp/merge-lib.sh
source "$_MERGE_CURSOR_DIR/mcp/merge-lib.sh"

# Upsert servers from a JSON object; delete keys listed in a JSON array.
# Usage: merge_cursor_mcp <mcp.json> <upsert.json> [remove.json]
merge_cursor_mcp() {
  merge_mcp "$@"
}

# One-shot: strip managed RTK Shell hooks from hooks.json (legacy cleanup).
merge_cursor_hooks_remove() {
  local hooks_json=$1
  local jq=${JQ:-jq}
  local tmp

  [[ -s $hooks_json ]] || return 0

  tmp=$(mktemp "$hooks_json.XXXXXX")
  if ! "$jq" '
    .hooks = (.hooks // {})
    | .hooks.preToolUse = [
        ((.hooks.preToolUse // [])[])
        | select((.command // "") | (contains("rtk-rewrite") or contains("rtk hook")) | not)
      ]
  ' "$hooks_json" >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  mv -f "$tmp" "$hooks_json"
}

# One-shot: drop managed RTK terminalAllowlist entries; delete the key if empty
# so Cursor falls back to the IDE-managed allowlist.
merge_cursor_permissions_clear_rtk() {
  local perm_json=$1
  local rtk_path=${2:-$HOME/.cursor/bin/rtk}
  local jq=${JQ:-jq}
  local tmp stripped

  [[ -s $perm_json ]] || return 0

  stripped=$(mktemp)
  tmp=$(mktemp "$perm_json.XXXXXX")
  if ! sed -E '/^[[:space:]]*\/\//d; s/[[:space:]]+\/\/.*$//' <"$perm_json" >"$stripped"; then
    rm -f "$tmp" "$stripped"
    return 1
  fi
  if ! "$jq" --arg rtk "$rtk_path" '
    .terminalAllowlist = [
      ((.terminalAllowlist // [])[])
      | select(. != "rtk" and (. != $rtk or $rtk == ""))
    ]
    | if (.terminalAllowlist | length) == 0 then del(.terminalAllowlist) else . end
  ' "$stripped" >"$tmp"; then
    rm -f "$tmp" "$stripped"
    return 1
  fi
  rm -f "$stripped"
  mv -f "$tmp" "$perm_json"
}

# Add or drop brave-search / firecrawl from env keys. Other servers stay.
# Usage: merge_cursor_mcp_secrets <mcp.json> <brave-cmd> <firecrawl-cmd>
merge_cursor_mcp_secrets() {
  local mcp_json=$1
  local brave_cmd=$2
  local firecrawl_cmd=$3
  local jq=${JQ:-jq}
  local upsert remove rc

  upsert=$(mktemp)
  remove=$(mktemp)
  if ! "$jq" -n \
    --arg brave "$brave_cmd" \
    --arg firecrawl "$firecrawl_cmd" \
    --arg brave_key "${BRAVE_API_KEY:-}" \
    --arg firecrawl_key "${FIRECRAWL_API_KEY:-}" \
    '
      {}
      | (if $brave_key != "" then
          . + { "brave-search": { command: $brave, env: { BRAVE_API_KEY: $brave_key } } }
        else . end)
      | (if $firecrawl_key != "" then
          . + { firecrawl: { command: $firecrawl, env: { FIRECRAWL_API_KEY: $firecrawl_key } } }
        else . end)
    ' >"$upsert"; then
    rm -f "$upsert" "$remove"
    return 1
  fi
  if ! "$jq" -n \
    --arg brave_key "${BRAVE_API_KEY:-}" \
    --arg firecrawl_key "${FIRECRAWL_API_KEY:-}" \
    '
      [ (if $brave_key == "" then "brave-search" else empty end),
        (if $firecrawl_key == "" then "firecrawl" else empty end) ]
    ' >"$remove"; then
    rm -f "$upsert" "$remove"
    return 1
  fi
  merge_cursor_mcp "$mcp_json" "$upsert" "$remove"
  rc=$?
  rm -f "$upsert" "$remove"
  return "$rc"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  set -euo pipefail
  cmd=${1:-}
  shift || true
  case $cmd in
    mcp) merge_cursor_mcp "$@" ;;
    mcp-secrets) merge_cursor_mcp_secrets "$@" ;;
    hooks-remove) merge_cursor_hooks_remove "$@" ;;
    permissions-clear-rtk) merge_cursor_permissions_clear_rtk "$@" ;;
    *)
      echo "usage: $0 mcp <mcp.json> <upsert.json> [remove.json] | mcp-secrets <mcp.json> <brave-cmd> <firecrawl-cmd> | hooks-remove <hooks.json> | permissions-clear-rtk <permissions.json> [absolute-rtk]" >&2
      exit 2
      ;;
  esac
fi
