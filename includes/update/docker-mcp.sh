#!/usr/bin/env bash
# Refresh the Docker Engine MCP image pin in home/llm-context.nix.
# Prefer a semver tag; fall back to the latest digest if none exist.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

refresh_docker_mcp() {
  local root file image tag digest
  root=$(update_repo_root)
  file=$root/home/llm-context.nix
  if tag=$(docker_hub_latest_semver mcp/docker 2>/dev/null); then
    image=mcp/docker:$tag
  else
    digest=$(docker_hub_tag_digest mcp/docker latest)
    image=mcp/docker@$digest
  fi
  echo "docker-mcp: $image"
  replace_nix_string_assign "$file" dockerMcpImage "$image"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_docker_mcp "$@"
fi
