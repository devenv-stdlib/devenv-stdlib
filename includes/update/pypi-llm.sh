#!/usr/bin/env bash
# Refresh Headroom and Serena pins in home/llm-context.nix from PyPI.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

refresh_pypi_llm() {
  local root file headroom serena
  root=$(update_repo_root)
  file=$root/home/llm-context.nix
  headroom=$(pypi_latest headroom-ai)
  serena=$(pypi_latest serena-agent)
  echo "headroom-ai: $headroom"
  echo "serena-agent: $serena"
  replace_nix_string_assign "$file" headroomVersion "$headroom"
  replace_nix_string_assign "$file" serenaVersion "$serena"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_pypi_llm "$@"
fi
