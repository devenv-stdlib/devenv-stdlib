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

merge_cursor_mcp() {
  local mcp_json=$1
  local serena_command=$2
  local headroom_command=$3
  local jq=${JQ:-jq}
  local dir tmp

  dir=$(dirname "$mcp_json")
  mkdir -p "$dir"

  tmp=$(mktemp "$mcp_json.XXXXXX")
  if [[ -s "$mcp_json" ]]; then
    if ! "$jq" --arg serena "$serena_command" --arg headroom "$headroom_command" '
      .mcpServers = (.mcpServers // {})
      | .mcpServers.serena = {
          command: $serena,
          args: ["start-mcp-server", "--context", "ide"]
        }
      | .mcpServers.headroom = {
          command: $headroom,
          args: ["mcp", "serve", "--proxy-url", "http://127.0.0.1:8787"]
        }
    ' "$mcp_json" >"$tmp"; then
      rm -f "$tmp"
      return 1
    fi
  else
    if ! "$jq" --null-input --arg serena "$serena_command" --arg headroom "$headroom_command" '
      {
        mcpServers: {
          serena: {
            command: $serena,
            args: ["start-mcp-server", "--context", "ide"]
          },
          headroom: {
            command: $headroom,
            args: ["mcp", "serve", "--proxy-url", "http://127.0.0.1:8787"]
          }
        }
      }
    ' >"$tmp"; then
      rm -f "$tmp"
      return 1
    fi
  fi
  mv -f "$tmp" "$mcp_json"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  set -euo pipefail
  cmd=${1:-}
  shift || true
  case $cmd in
    hooks) merge_cursor_hooks "$@" ;;
    mcp) merge_cursor_mcp "$@" ;;
    *)
      echo "usage: $0 hooks <hooks.json> <rtk-rewrite> | mcp <mcp.json> <serena> <headroom>" >&2
      exit 2
      ;;
  esac
fi
