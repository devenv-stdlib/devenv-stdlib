#!/usr/bin/env bats
# shellcheck disable=SC2016,SC2030,SC2031
# ^ SC2030/SC2031: each @test looks like a subshell, so secret exports are
# reported as leaking or getting lost; they are deliberately per-test.
# Fingerprint + skip/upsert for home/watch-mcp-secrets.sh. No live MCP.

bats_require_minimum_version 1.5.0

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$REPO_DIR/home/watch-mcp-secrets.sh"
  command -v sha256sum >/dev/null || skip "sha256sum not installed"
  TMP=$(mktemp -d)
  export HOME="$TMP/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export MCP_SECRETS_FINGERPRINT="$TMP/fp"
  mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$TMP/proj"
  unset BRAVE_API_KEY FIRECRAWL_API_KEY
}

teardown() {
  rm -rf "$TMP"
}

@test "sync is a no-op when the fingerprint is unchanged" {
  export BRAVE_API_KEY=a FIRECRAWL_API_KEY=b
  hash=$(mcp_secrets_fingerprint)
  printf '%s\n' "$hash" >"$MCP_SECRETS_FINGERPRINT"
  before=$(cat "$MCP_SECRETS_FINGERPRINT")
  export MCP_SECRETS_WRAPPERS="$TMP/missing-wrappers.env"
  run mcp_secrets_sync "$TMP/proj"
  [ "$status" -eq 0 ]
  [ "$(cat "$MCP_SECRETS_FINGERPRINT")" = "$before" ]
}

@test "sync stores a fingerprint when keys change and wrappers are missing" {
  export BRAVE_API_KEY=new FIRECRAWL_API_KEY=new
  export MCP_SECRETS_WRAPPERS="$TMP/missing-wrappers.env"
  run mcp_secrets_sync "$TMP/proj"
  [ "$status" -eq 0 ]
  [ -s "$MCP_SECRETS_FINGERPRINT" ]
}

@test "failed mcp-secrets merge does not update the fingerprint" {
  command -v jq >/dev/null || skip "jq not installed"
  export BRAVE_API_KEY=x
  mkdir -p "$HOME/.cursor" "$(mcp_secrets_host_dir)"
  # Invalid mcp.json makes merge_cursor_mcp_secrets fail.
  printf 'not-json\n' >"$HOME/.cursor/mcp.json"
  printf 'BRAVE_MCP=/tmp/brave-mcp\nFIRECRAWL_MCP=/tmp/fire-mcp\n' >"$(mcp_secrets_wrappers_file)"
  run mcp_secrets_sync "$TMP/proj"
  [ "$status" -ne 0 ]
  [ ! -f "$MCP_SECRETS_FINGERPRINT" ]
}

@test "sync sources Home Manager store paths when siblings are missing" {
  export MCP_SECRETS_LOAD_SECRETS_SH="$TMP/load.sh"
  export MCP_SECRETS_MERGE_CURSOR_SH="$TMP/merge.sh"
  printf 'home_load_secrets() { :; }\n' >"$MCP_SECRETS_LOAD_SECRETS_SH"
  printf 'merge_cursor_mcp_secrets() { echo sourced-from-env >>"%s"; }\n' "$TMP/mark" >"$MCP_SECRETS_MERGE_CURSOR_SH"
  mkdir -p "$(mcp_secrets_host_dir)"
  printf 'BRAVE_MCP=/tmp/brave\nFIRECRAWL_MCP=/tmp/fire\n' >"$(mcp_secrets_wrappers_file)"
  export BRAVE_API_KEY=k
  run mcp_secrets_sync "$TMP/proj"
  [ "$status" -eq 0 ]
  grep -q sourced-from-env "$TMP/mark"
}

@test "sync upserts Brave into mcp.json when wrappers exist" {
  command -v jq >/dev/null || skip "jq not installed"
  mkdir -p "$HOME/.cursor" "$(mcp_secrets_host_dir)"
  printf 'BRAVE_MCP=/tmp/brave-mcp\nFIRECRAWL_MCP=/tmp/fire-mcp\n' >"$(mcp_secrets_wrappers_file)"
  printf '%s\n' '{"mcpServers":{"serena":{"command":"/old/serena"}}}' >"$HOME/.cursor/mcp.json"
  export BRAVE_API_KEY=secret-brave
  unset FIRECRAWL_API_KEY
  run mcp_secrets_sync "$TMP/proj"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.mcpServers["brave-search"].env.BRAVE_API_KEY' "$HOME/.cursor/mcp.json")" = "secret-brave" ]
  [ "$(jq -r '.mcpServers.firecrawl // empty' "$HOME/.cursor/mcp.json")" = "" ]
  [ "$(jq -r '.mcpServers.serena.command' "$HOME/.cursor/mcp.json")" = "/old/serena" ]
}
