#!/usr/bin/env bash
# Merge Cursor hooks.json / mcp.json without replacing user entries.
# Sourced by tests; executed from home.activation.
# shellcheck disable=SC2016

merge_cursor_hooks() {
  local hooks_json=$1
  local rtk_command=$2
  local jq=${JQ:-jq}
  local dir tmp

  dir=$(dirname "$hooks_json")
  mkdir -p "$dir"

  tmp=$(mktemp "$hooks_json.XXXXXX")
  if [[ -s "$hooks_json" ]]; then
    if ! "$jq" --arg cmd "$rtk_command" '
      .version = (.version // 1)
      | .hooks = (.hooks // {})
      | .hooks.preToolUse = (
          [((.hooks.preToolUse // [])[])
            | select((.command // "") | (contains("rtk-rewrite") or contains("rtk hook")) | not)]
          + [{ matcher: "Shell", command: $cmd }]
        )
    ' "$hooks_json" >"$tmp"; then
      rm -f "$tmp"
      return 1
    fi
  else
    if ! "$jq" --null-input --arg cmd "$rtk_command" '
      {
        version: 1,
        hooks: {
          preToolUse: [{ matcher: "Shell", command: $cmd }]
        }
      }
    ' >"$tmp"; then
      rm -f "$tmp"
      return 1
    fi
  fi
  mv -f "$tmp" "$hooks_json"
}

# Drop managed RTK Shell hooks. Other preToolUse entries stay.
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

# Upsert servers from a JSON object; delete keys listed in a JSON array.
# Usage: merge_cursor_mcp <mcp.json> <upsert.json> [remove.json]
merge_cursor_mcp() {
  local mcp_json=$1
  local upsert_json=$2
  local remove_json=${3:-}
  local jq=${JQ:-jq}
  local dir tmp remove_arg

  dir=$(dirname "$mcp_json")
  mkdir -p "$dir"

  if [[ -n $remove_json ]]; then
    remove_arg=$remove_json
  else
    remove_arg=$(mktemp)
    echo '[]' >"$remove_arg"
  fi

  tmp=$(mktemp "$mcp_json.XXXXXX")
  if [[ -s "$mcp_json" ]]; then
    if ! "$jq" --slurpfile up "$upsert_json" --slurpfile rm "$remove_arg" '
      .mcpServers = (.mcpServers // {})
      | .mcpServers = (.mcpServers + ($up[0] // {}))
      | reduce (($rm[0] // [])[]) as $k (.; del(.mcpServers[$k]))
    ' "$mcp_json" >"$tmp"; then
      rm -f "$tmp"
      [[ -z $remove_json ]] && rm -f "$remove_arg"
      return 1
    fi
  else
    if ! "$jq" --null-input --slurpfile up "$upsert_json" --slurpfile rm "$remove_arg" '
      { mcpServers: ($up[0] // {}) }
      | reduce (($rm[0] // [])[]) as $k (.; del(.mcpServers[$k]))
    ' >"$tmp"; then
      rm -f "$tmp"
      [[ -z $remove_json ]] && rm -f "$remove_arg"
      return 1
    fi
  fi
  [[ -z $remove_json ]] && rm -f "$remove_arg"
  mv -f "$tmp" "$mcp_json"
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
    hooks) merge_cursor_hooks "$@" ;;
    hooks-remove) merge_cursor_hooks_remove "$@" ;;
    mcp) merge_cursor_mcp "$@" ;;
    mcp-secrets) merge_cursor_mcp_secrets "$@" ;;
    *)
      echo "usage: $0 hooks <hooks.json> <rtk-rewrite> | hooks-remove <hooks.json> | mcp <mcp.json> <upsert.json> [remove.json] | mcp-secrets <mcp.json> <brave-cmd> <firecrawl-cmd>" >&2
      exit 2
      ;;
  esac
fi
