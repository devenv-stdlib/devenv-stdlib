#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# ^ SC2030/SC2031: each @test looks like a subshell, so API key exports are
# reported as leaking or getting lost; they are deliberately per-test.
# Exercises home/ides/merge-cursor-llm.sh. Does not run home-manager switch
# or `mise install`.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$REPO_DIR/home/ides/merge-cursor-llm.sh"
  command -v jq >/dev/null || skip "jq not installed"
  TMP=$(mktemp -d)
  HOOKS="$TMP/.cursor/hooks.json"
  MCP="$TMP/.cursor/mcp.json"
  SERENA_CMD="$TMP/.local/bin/serena"
  HEADROOM_CMD="$TMP/.local/bin/headroom"
  GITHUB_CMD="$TMP/.local/bin/github-mcp"
  DOCKER_CMD="$TMP/.local/bin/docker-mcp"
  BRAVE_CMD="$TMP/.local/bin/brave-search-mcp"
  FIRECRAWL_CMD="$TMP/.local/bin/firecrawl-mcp"
  UPSERT="$TMP/upsert.json"
  REMOVE="$TMP/remove.json"
}

write_core_upsert() {
  jq -n \
    --arg serena "$SERENA_CMD" \
    --arg headroom "$HEADROOM_CMD" \
    --arg github "$GITHUB_CMD" \
    --arg docker "$DOCKER_CMD" \
    '{
      serena: { command: $serena, args: ["start-mcp-server", "--context", "ide", "--open-web-dashboard", "false"] },
      headroom: { command: $headroom, args: ["mcp", "serve"] },
      context7: { url: "https://mcp.context7.com/mcp" },
      github: { command: $github },
      docker: { command: $docker }
    }' >"$UPSERT"
}

teardown() {
  rm -rf "$TMP"
}

@test "creates mcp.json with core servers and no optional crawl MCPs" {
  write_core_upsert
  echo '[]' >"$REMOVE"
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"
  [ "$(jq -r '.mcpServers.serena.command' "$MCP")" = "$SERENA_CMD" ]
  [ "$(jq -r '.mcpServers.serena.args | join(" ")' "$MCP")" = "start-mcp-server --context ide --open-web-dashboard false" ]
  [ "$(jq -r '.mcpServers.headroom.command' "$MCP")" = "$HEADROOM_CMD" ]
  [ "$(jq -r '.mcpServers.headroom.args | join(" ")' "$MCP")" = "mcp serve" ]
  [ "$(jq -r '.mcpServers.context7.url' "$MCP")" = "https://mcp.context7.com/mcp" ]
  [ "$(jq -r '.mcpServers.github.command' "$MCP")" = "$GITHUB_CMD" ]
  [ "$(jq -r '.mcpServers.docker.command' "$MCP")" = "$DOCKER_CMD" ]
  [ "$(jq -r '.mcpServers["brave-search"] // empty' "$MCP")" = "" ]
  [ "$(jq -r '.mcpServers.firecrawl // empty' "$MCP")" = "" ]
  [ "$(jq -r '.mcpServers | keys | length' "$MCP")" -eq 5 ]
}

@test "preserves foreign MCP servers and upserts managed ones" {
  mkdir -p "$(dirname "$MCP")"
  cat >"$MCP" <<'EOF'
{
  "mcpServers": {
    "user-notes": {
      "command": "npx",
      "args": ["-y", "notes-mcp"]
    },
    "serena": {
      "command": "/old/serena",
      "args": ["start-mcp-server"]
    }
  }
}
EOF
  write_core_upsert
  echo '[]' >"$REMOVE"
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"
  [ "$(jq -r '.mcpServers["user-notes"].command' "$MCP")" = "npx" ]
  [ "$(jq -r '.mcpServers["user-notes"].args[1]' "$MCP")" = "notes-mcp" ]
  [ "$(jq -r '.mcpServers.serena.command' "$MCP")" = "$SERENA_CMD" ]
  [ "$(jq -r '.mcpServers.serena.args[2]' "$MCP")" = "ide" ]
  [ "$(jq -r '.mcpServers.headroom.command' "$MCP")" = "$HEADROOM_CMD" ]
  [ "$(jq -r '.mcpServers.context7.url' "$MCP")" = "https://mcp.context7.com/mcp" ]
  [ "$(jq -r '.mcpServers.github.command' "$MCP")" = "$GITHUB_CMD" ]
}

@test "MCP merge is idempotent" {
  write_core_upsert
  echo '[]' >"$REMOVE"
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"
  first=$(jq -cS . "$MCP")
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"
  [ "$(jq -cS . "$MCP")" = "$first" ]
}

@test "upserts Brave and Firecrawl from JSON without real secrets" {
  write_core_upsert
  jq --arg brave "$BRAVE_CMD" --arg firecrawl "$FIRECRAWL_CMD" \
    '. + {
      "brave-search": { command: $brave, env: { BRAVE_API_KEY: "REDACTED" } },
      firecrawl: { command: $firecrawl, env: { FIRECRAWL_API_KEY: "REDACTED" } }
    }' "$UPSERT" >"$UPSERT.next"
  mv -f "$UPSERT.next" "$UPSERT"
  echo '[]' >"$REMOVE"
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"
  [ "$(jq -r '.mcpServers["brave-search"].command' "$MCP")" = "$BRAVE_CMD" ]
  [ "$(jq -r '.mcpServers["brave-search"].env.BRAVE_API_KEY' "$MCP")" = "REDACTED" ]
  [ "$(jq -r '.mcpServers.firecrawl.command' "$MCP")" = "$FIRECRAWL_CMD" ]
  [ "$(jq -r '.mcpServers.firecrawl.env.FIRECRAWL_API_KEY' "$MCP")" = "REDACTED" ]
}

@test "removes Brave and Firecrawl when listed in remove.json" {
  write_core_upsert
  jq --arg brave "$BRAVE_CMD" --arg firecrawl "$FIRECRAWL_CMD" \
    '. + {
      "brave-search": { command: $brave, env: { BRAVE_API_KEY: "REDACTED" } },
      firecrawl: { command: $firecrawl, env: { FIRECRAWL_API_KEY: "REDACTED" } }
    }' "$UPSERT" >"$UPSERT.next"
  mv -f "$UPSERT.next" "$UPSERT"
  echo '[]' >"$REMOVE"
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"

  write_core_upsert
  printf '%s\n' '["brave-search","firecrawl"]' >"$REMOVE"
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"
  [ "$(jq -r '.mcpServers["brave-search"] // empty' "$MCP")" = "" ]
  [ "$(jq -r '.mcpServers.firecrawl // empty' "$MCP")" = "" ]
  [ "$(jq -r '.mcpServers.serena.command' "$MCP")" = "$SERENA_CMD" ]
  [ "$(jq -r '.mcpServers.context7.url' "$MCP")" = "https://mcp.context7.com/mcp" ]
}

@test "mcp CLI upserts from JSON files" {
  write_core_upsert
  echo '[]' >"$REMOVE"
  "$REPO_DIR/home/ides/merge-cursor-llm.sh" mcp "$MCP" "$UPSERT" "$REMOVE"
  [ "$(jq -r '.mcpServers.github.command' "$MCP")" = "$GITHUB_CMD" ]
  [ "$(jq -r '.mcpServers.docker.command' "$MCP")" = "$DOCKER_CMD" ]
}

@test "mcp-secrets upserts Brave and Firecrawl from env keys" {
  write_core_upsert
  echo '[]' >"$REMOVE"
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"
  export BRAVE_API_KEY=test-brave FIRECRAWL_API_KEY=test-fire
  merge_cursor_mcp_secrets "$MCP" "$BRAVE_CMD" "$FIRECRAWL_CMD"
  [ "$(jq -r '.mcpServers["brave-search"].command' "$MCP")" = "$BRAVE_CMD" ]
  [ "$(jq -r '.mcpServers["brave-search"].env.BRAVE_API_KEY' "$MCP")" = "test-brave" ]
  [ "$(jq -r '.mcpServers.firecrawl.env.FIRECRAWL_API_KEY' "$MCP")" = "test-fire" ]
  [ "$(jq -r '.mcpServers.serena.command' "$MCP")" = "$SERENA_CMD" ]
}

@test "hooks-remove drops legacy RTK entries and keeps other preToolUse hooks" {
  mkdir -p "$(dirname "$HOOKS")"
  cat >"$HOOKS" <<'EOF'
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      { "matcher": "Read", "command": "/usr/local/bin/audit-read" },
      { "matcher": "Shell", "command": "/nix/store/rtk-rewrite-test/bin/rtk-rewrite.sh" },
      { "matcher": "Shell", "command": "rtk hook cursor" }
    ]
  }
}
EOF
  merge_cursor_hooks_remove "$HOOKS"
  [ "$(jq -r '.hooks.preToolUse | length' "$HOOKS")" -eq 1 ]
  [ "$(jq -r '.hooks.preToolUse[0].command' "$HOOKS")" = "/usr/local/bin/audit-read" ]
}

@test "hooks-remove CLI is a no-op when hooks.json is missing" {
  "$REPO_DIR/home/ides/merge-cursor-llm.sh" hooks-remove "$HOOKS"
  [ ! -e "$HOOKS" ]
}

@test "mcp-secrets removes Brave and Firecrawl when keys are empty" {
  write_core_upsert
  echo '[]' >"$REMOVE"
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"
  export BRAVE_API_KEY=keep FIRECRAWL_API_KEY=keep
  merge_cursor_mcp_secrets "$MCP" "$BRAVE_CMD" "$FIRECRAWL_CMD"
  unset BRAVE_API_KEY FIRECRAWL_API_KEY
  merge_cursor_mcp_secrets "$MCP" "$BRAVE_CMD" "$FIRECRAWL_CMD"
  [ "$(jq -r '.mcpServers["brave-search"] // empty' "$MCP")" = "" ]
  [ "$(jq -r '.mcpServers.firecrawl // empty' "$MCP")" = "" ]
  [ "$(jq -r '.mcpServers.serena.command' "$MCP")" = "$SERENA_CMD" ]
}

@test "permissions-clear-rtk drops managed entries and deletes empty key" {
  PERM="$TMP/.cursor/permissions.json"
  RTK_BIN="$TMP/.cursor/bin/rtk"
  mkdir -p "$(dirname "$PERM")"
  jq -n --arg rtk "$RTK_BIN" '{terminalAllowlist: [$rtk, "rtk"], mcpAllowlist: ["github:*"]}' >"$PERM"
  merge_cursor_permissions_clear_rtk "$PERM" "$RTK_BIN"
  [ "$(jq -r 'has("terminalAllowlist")' "$PERM")" = "false" ]
  [ "$(jq -r '.mcpAllowlist[0]' "$PERM")" = "github:*" ]
}

@test "permissions-clear-rtk CLI clears rtk allowlist" {
  PERM="$TMP/.cursor/permissions.json"
  RTK_BIN="$TMP/.cursor/bin/rtk"
  mkdir -p "$(dirname "$PERM")"
  jq -n --arg rtk "$RTK_BIN" '{terminalAllowlist: [$rtk, "rtk"]}' >"$PERM"
  "$REPO_DIR/home/ides/merge-cursor-llm.sh" permissions-clear-rtk "$PERM" "$RTK_BIN"
  [ "$(jq -r 'has("terminalAllowlist")' "$PERM")" = "false" ]
}
