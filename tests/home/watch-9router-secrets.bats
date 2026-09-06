#!/usr/bin/env bats
# shellcheck disable=SC2016,SC2030,SC2031
# ^ SC2030/SC2031: each @test looks like a subshell, so secret exports are
# reported as leaking or getting lost; they are deliberately per-test.
# Fingerprint + skip/upsert for home/watch-9router-secrets.sh. No live 9Router.

bats_require_minimum_version 1.5.0

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$REPO_DIR/home/watch-9router-secrets.sh"
  command -v sha256sum >/dev/null || skip "sha256sum not installed"
  TMP=$(mktemp -d)
  export HOME="$TMP/home"
  export NINEROUTER_SECRETS_FINGERPRINT="$TMP/fp"
  mkdir -p "$HOME" "$TMP/proj"
  unset BRAVE_API_KEY FIRECRAWL_API_KEY INITIAL_PASSWORD
}

teardown() {
  rm -rf "$TMP"
}

@test "sync is a no-op when the fingerprint is unchanged" {
  export BRAVE_API_KEY=a FIRECRAWL_API_KEY=b INITIAL_PASSWORD=c
  nine_router_secrets_fingerprint >"$NINEROUTER_SECRETS_FINGERPRINT"
  printf '#!/bin/sh\necho ran >>"$NINEROUTER_SECRETS_FINGERPRINT.ran"\n' >"$TMP/hook"
  chmod +x "$TMP/hook"
  export NINEROUTER_SYNC_HOOK="$TMP/hook"
  run nine_router_sync_secrets "$TMP/proj"
  [ "$status" -eq 0 ]
  [ ! -f "$NINEROUTER_SECRETS_FINGERPRINT.ran" ]
}

@test "sync runs the hook and stores a fingerprint when keys change" {
  export BRAVE_API_KEY=new FIRECRAWL_API_KEY=new INITIAL_PASSWORD=pw
  printf '#!/bin/sh\necho ran >>"%s.ran"\n' "$NINEROUTER_SECRETS_FINGERPRINT" >"$TMP/hook"
  chmod +x "$TMP/hook"
  export NINEROUTER_SYNC_HOOK="$TMP/hook"
  run nine_router_sync_secrets "$TMP/proj"
  [ "$status" -eq 0 ]
  [ -f "$NINEROUTER_SECRETS_FINGERPRINT.ran" ]
  [ -s "$NINEROUTER_SECRETS_FINGERPRINT" ]
}

@test "failed hook does not update the fingerprint" {
  export BRAVE_API_KEY=x
  printf '#!/bin/sh\nexit 1\n' >"$TMP/hook"
  chmod +x "$TMP/hook"
  export NINEROUTER_SYNC_HOOK="$TMP/hook"
  run nine_router_sync_secrets "$TMP/proj"
  [ "$status" -ne 0 ]
  [ ! -f "$NINEROUTER_SECRETS_FINGERPRINT" ]
}

@test "sync upserts Brave into mcp.json when wrappers exist" {
  command -v jq >/dev/null || skip "jq not installed"
  mkdir -p "$HOME/.cursor" "$HOME/.config/9router"
  printf 'BRAVE_MCP=/tmp/brave-mcp\nFIRECRAWL_MCP=/tmp/fire-mcp\n' >"$HOME/.config/9router/mcp-wrappers.env"
  printf '%s\n' '{"mcpServers":{"serena":{"command":"/old/serena"}}}' >"$HOME/.cursor/mcp.json"
  export BRAVE_API_KEY=secret-brave
  unset FIRECRAWL_API_KEY
  printf '#!/bin/sh\nexit 0\n' >"$TMP/hook"
  chmod +x "$TMP/hook"
  export NINEROUTER_SYNC_HOOK="$TMP/hook"
  run nine_router_sync_secrets "$TMP/proj"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.mcpServers["brave-search"].env.BRAVE_API_KEY' "$HOME/.cursor/mcp.json")" = "secret-brave" ]
  [ "$(jq -r '.mcpServers.firecrawl // empty' "$HOME/.cursor/mcp.json")" = "" ]
  [ "$(jq -r '.mcpServers.serena.command' "$HOME/.cursor/mcp.json")" = "/old/serena" ]
}
