#!/usr/bin/env bash
# Harness-agnostic mcp.json upsert/remove. Preserves user-added servers.
# Sourced by merge-cursor-llm.sh and future harness wrappers.
# shellcheck disable=SC2016

# Upsert servers from a JSON object; delete keys listed in a JSON array.
# Never replaces the whole mcpServers object or deletes unknown keys.
# Usage: merge_mcp <mcp.json> <upsert.json> [remove.json]
merge_mcp() {
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
