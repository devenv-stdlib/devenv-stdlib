#!/usr/bin/env bats
# Exercises home/merge-cursor-llm.sh. Does not run home-manager switch,
# the Headroom proxy, or `uv tool install`.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$REPO_DIR/home/merge-cursor-llm.sh"
  command -v jq >/dev/null || skip "jq not installed"
  TMP=$(mktemp -d)
  HOOKS="$TMP/.cursor/hooks.json"
  MCP="$TMP/.cursor/mcp.json"
  RTK_CMD="/nix/store/rtk-rewrite-test/bin/rtk-rewrite.sh"
  SERENA_CMD="$TMP/.local/bin/serena"
  HEADROOM_CMD="$TMP/.local/bin/headroom"
}

teardown() {
  rm -rf "$TMP"
}

@test "creates hooks.json with version 1 and an RTK Shell matcher" {
  merge_cursor_hooks "$HOOKS" "$RTK_CMD"
  [ "$(jq -r '.version' "$HOOKS")" = "1" ]
  [ "$(jq -r '.hooks.preToolUse | length' "$HOOKS")" -eq 1 ]
  [ "$(jq -r '.hooks.preToolUse[0].matcher' "$HOOKS")" = "Shell" ]
  [ "$(jq -r '.hooks.preToolUse[0].command' "$HOOKS")" = "$RTK_CMD" ]
}

@test "keeps non-RTK preToolUse entries and upserts RTK" {
  mkdir -p "$(dirname "$HOOKS")"
  cat >"$HOOKS" <<'EOF'
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      { "matcher": "Read", "command": "/usr/local/bin/audit-read" },
      { "matcher": "Shell", "command": "rtk hook cursor" }
    ]
  }
}
EOF
  merge_cursor_hooks "$HOOKS" "$RTK_CMD"
  [ "$(jq -r '.version' "$HOOKS")" = "1" ]
  [ "$(jq -r '[.hooks.preToolUse[] | select(.command == "/usr/local/bin/audit-read")] | length' "$HOOKS")" -eq 1 ]
  [ "$(jq -r '[.hooks.preToolUse[] | select(.command | test("rtk-rewrite|rtk hook"))] | length' "$HOOKS")" -eq 1 ]
  [ "$(jq -r '.hooks.preToolUse[] | select(.matcher == "Shell" and (.command | test("rtk-rewrite"))).command' "$HOOKS")" = "$RTK_CMD" ]
}

@test "hooks merge is idempotent and does not drop version 1" {
  merge_cursor_hooks "$HOOKS" "$RTK_CMD"
  merge_cursor_hooks "$HOOKS" "$RTK_CMD"
  [ "$(jq -r '.version' "$HOOKS")" = "1" ]
  [ "$(jq -r '[.hooks.preToolUse[] | select(.command | test("rtk-rewrite"))] | length' "$HOOKS")" -eq 1 ]
}

@test "adds version 1 when hooks.json has none" {
  mkdir -p "$(dirname "$HOOKS")"
  cat >"$HOOKS" <<'EOF'
{
  "hooks": {
    "preToolUse": [
      { "matcher": "Read", "command": "echo foreign" }
    ]
  }
}
EOF
  merge_cursor_hooks "$HOOKS" "$RTK_CMD"
  [ "$(jq -r '.version' "$HOOKS")" = "1" ]
  [ "$(jq -r '.hooks.preToolUse[] | select(.command == "echo foreign").matcher' "$HOOKS")" = "Read" ]
}

@test "creates mcp.json with serena and headroom only" {
  merge_cursor_mcp "$MCP" "$SERENA_CMD" "$HEADROOM_CMD"
  [ "$(jq -r '.mcpServers.serena.command' "$MCP")" = "$SERENA_CMD" ]
  [ "$(jq -r '.mcpServers.serena.args | join(" ")' "$MCP")" = "start-mcp-server --context ide" ]
  [ "$(jq -r '.mcpServers.headroom.command' "$MCP")" = "$HEADROOM_CMD" ]
  [ "$(jq -r '.mcpServers.headroom.args | join(" ")' "$MCP")" = "mcp serve --proxy-url http://127.0.0.1:8787" ]
  [ "$(jq -r '.mcpServers | keys | length' "$MCP")" -eq 2 ]
}

@test "preserves foreign MCP servers and upserts serena and headroom" {
  mkdir -p "$(dirname "$MCP")"
  cat >"$MCP" <<'EOF'
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"]
    },
    "serena": {
      "command": "/old/serena",
      "args": ["start-mcp-server"]
    }
  }
}
EOF
  merge_cursor_mcp "$MCP" "$SERENA_CMD" "$HEADROOM_CMD"
  [ "$(jq -r '.mcpServers.github.command' "$MCP")" = "npx" ]
  [ "$(jq -r '.mcpServers.github.args[1]' "$MCP")" = "@modelcontextprotocol/server-github" ]
  [ "$(jq -r '.mcpServers.serena.command' "$MCP")" = "$SERENA_CMD" ]
  [ "$(jq -r '.mcpServers.serena.args[2]' "$MCP")" = "ide" ]
  [ "$(jq -r '.mcpServers.headroom.command' "$MCP")" = "$HEADROOM_CMD" ]
}

@test "MCP merge is idempotent" {
  merge_cursor_mcp "$MCP" "$SERENA_CMD" "$HEADROOM_CMD"
  first=$(jq -cS . "$MCP")
  merge_cursor_mcp "$MCP" "$SERENA_CMD" "$HEADROOM_CMD"
  [ "$(jq -cS . "$MCP")" = "$first" ]
}
