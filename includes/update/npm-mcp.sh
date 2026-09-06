#!/usr/bin/env bash
# Refresh official Brave + Firecrawl npm pins in home/llm-context.nix.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

refresh_npm_mcp() {
  local root file brave firecrawl
  root=$(update_repo_root)
  file=$root/home/llm-context.nix
  brave=$(npm_latest @brave/brave-search-mcp-server)
  firecrawl=$(npm_latest firecrawl-mcp)
  echo "@brave/brave-search-mcp-server: $brave"
  echo "firecrawl-mcp: $firecrawl"
  replace_nix_string_assign "$file" braveSearchMcpVersion "$brave"
  replace_nix_string_assign "$file" firecrawlMcpVersion "$firecrawl"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_npm_mcp "$@"
fi
