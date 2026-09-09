#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# ^ SC2030/SC2031: each @test looks like a subshell, so API key exports are
# reported as leaking or getting lost; they are deliberately per-test.
# Exercises home/merge-cursor-llm.sh. Does not run home-manager switch
# or `mise install`.

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
      serena: { command: $serena, args: ["start-mcp-server", "--context", "ide"] },
      headroom: { command: $headroom, args: ["mcp", "serve"] },
      context7: { url: "https://mcp.context7.com/mcp" },
      github: { command: $github },
      docker: { command: $docker }
    }' >"$UPSERT"
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

@test "creates mcp.json with core servers and no optional crawl MCPs" {
  write_core_upsert
  echo '[]' >"$REMOVE"
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"
  [ "$(jq -r '.mcpServers.serena.command' "$MCP")" = "$SERENA_CMD" ]
  [ "$(jq -r '.mcpServers.serena.args | join(" ")' "$MCP")" = "start-mcp-server --context ide" ]
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
  "$REPO_DIR/home/merge-cursor-llm.sh" mcp "$MCP" "$UPSERT" "$REMOVE"
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

@test "hooks-remove drops RTK entries and keeps other preToolUse hooks" {
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
  "$REPO_DIR/home/merge-cursor-llm.sh" hooks-remove "$HOOKS"
  [ ! -e "$HOOKS" ]
}

@test "removes Headroom MCP when switching to gateway mode" {
  write_core_upsert
  echo '[]' >"$REMOVE"
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"
  [ "$(jq -r '.mcpServers.headroom.command' "$MCP")" = "$HEADROOM_CMD" ]

  jq 'del(.headroom)' "$UPSERT" >"$UPSERT.next"
  mv -f "$UPSERT.next" "$UPSERT"
  printf '%s\n' '["headroom"]' >"$REMOVE"
  merge_cursor_mcp "$MCP" "$UPSERT" "$REMOVE"
  [ "$(jq -r '.mcpServers.headroom // empty' "$MCP")" = "" ]
  [ "$(jq -r '.mcpServers.serena.command' "$MCP")" = "$SERENA_CMD" ]
  [ "$(jq -r '.mcpServers.context7.url' "$MCP")" = "https://mcp.context7.com/mcp" ]
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

@test "permissions merge creates terminalAllowlist with absolute rtk and bare rtk" {
  PERM="$TMP/.cursor/permissions.json"
  RTK_BIN="$TMP/.cursor/bin/rtk"
  mkdir -p "$(dirname "$RTK_BIN")"
  merge_cursor_permissions "$PERM" "$RTK_BIN"
  [ "$(jq -r '.terminalAllowlist | join(" ")' "$PERM")" = "$RTK_BIN rtk" ]
}

@test "permissions merge replaces other prefixes; keeps other keys" {
  PERM="$TMP/.cursor/permissions.json"
  RTK_BIN="$TMP/.cursor/bin/rtk"
  mkdir -p "$(dirname "$PERM")"
  cat >"$PERM" <<'EOF'
{
  "mcpAllowlist": ["github:*"],
  "terminalAllowlist": ["git", "npm"]
}
EOF
  merge_cursor_permissions "$PERM" "$RTK_BIN"
  merge_cursor_permissions "$PERM" "$RTK_BIN"
  [ "$(jq -r '.terminalAllowlist | join(" ")' "$PERM")" = "$RTK_BIN rtk" ]
  [ "$(jq -r '.mcpAllowlist[0]' "$PERM")" = "github:*" ]
}

@test "permissions merge accepts JSONC line comments" {
  PERM="$TMP/.cursor/permissions.json"
  RTK_BIN="$TMP/.cursor/bin/rtk"
  mkdir -p "$(dirname "$PERM")"
  cat >"$PERM" <<'EOF'
{
  // host allowlist
  "terminalAllowlist": [
    "git" // prefix
  ]
}
EOF
  merge_cursor_permissions "$PERM" "$RTK_BIN"
  [ "$(jq -r '.terminalAllowlist | join(" ")' "$PERM")" = "$RTK_BIN rtk" ]
}

@test "permissions CLI sets absolute rtk allowlist" {
  PERM="$TMP/.cursor/permissions.json"
  RTK_BIN="$TMP/.cursor/bin/rtk"
  "$REPO_DIR/home/merge-cursor-llm.sh" permissions "$PERM" "$RTK_BIN"
  [ "$(jq -r '.terminalAllowlist | join(" ")' "$PERM")" = "$RTK_BIN rtk" ]
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
  "$REPO_DIR/home/merge-cursor-llm.sh" permissions-clear-rtk "$PERM" "$RTK_BIN"
  [ "$(jq -r 'has("terminalAllowlist")' "$PERM")" = "false" ]
}

run_rtk_hook() {
  local cmd=$1
  export RTK JQ
  jq -n --arg c "$cmd" '{tool_input:{command:$c}}' | bash "$REPO_DIR/home/rtk-rewrite.sh"
}

@test "rtk hook allows rewritten git with absolute RTK first token" {
  command -v rtk >/dev/null || skip "rtk not installed"
  RTK=$(command -v rtk)
  JQ=$(command -v jq)
  out=$(run_rtk_hook "git status")
  [ "$(jq -r '.permission' <<<"$out")" = "allow" ]
  [ "$(jq -r '.updated_input.command' <<<"$out")" = "$RTK git status" ]
  [ "$(jq -r '.updated_input.command | split(" ")[0]' <<<"$out")" = "$RTK" ]
}

@test "rtk hook wraps unfiltered commands with absolute rtk run" {
  command -v rtk >/dev/null || skip "rtk not installed"
  RTK=$(command -v rtk)
  JQ=$(command -v jq)
  out=$(run_rtk_hook "echo hello")
  [ "$(jq -r '.permission' <<<"$out")" = "allow" ]
  [[ "$(jq -r '.updated_input.command' <<<"$out")" == "$RTK"\ run\ -c\ * ]]
}

@test "rtk hook rewrites relative rtk commands to absolute and allows" {
  command -v rtk >/dev/null || skip "rtk not installed"
  RTK=$(command -v rtk)
  JQ=$(command -v jq)
  out=$(run_rtk_hook "rtk git status")
  [ "$(jq -r '.permission' <<<"$out")" = "allow" ]
  [ "$(jq -r '.updated_input.command' <<<"$out")" = "$RTK git status" ]
}

@test "allowlist first entry matches hook-emitted first token" {
  command -v rtk >/dev/null || skip "rtk not installed"
  PERM="$TMP/.cursor/permissions.json"
  RTK=$(command -v rtk)
  JQ=$(command -v jq)
  merge_cursor_permissions "$PERM" "$RTK"
  out=$(run_rtk_hook "git status")
  allow0=$(jq -r '.terminalAllowlist[0]' "$PERM")
  first=$(jq -r '.updated_input.command | split(" ")[0]' <<<"$out")
  [ "$allow0" = "$first" ]
  [ "$first" = "$RTK" ]
}
