#!/usr/bin/env bash
# Refresh home/github-mcp-pkg.nix from the latest GitHub release.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

github_mcp_asset() {
  case $1 in
    x86_64-linux) printf '%s\n' github-mcp-server_Linux_x86_64.tar.gz ;;
    aarch64-linux) printf '%s\n' github-mcp-server_Linux_arm64.tar.gz ;;
    x86_64-darwin) printf '%s\n' github-mcp-server_Darwin_x86_64.tar.gz ;;
    aarch64-darwin) printf '%s\n' github-mcp-server_Darwin_arm64.tar.gz ;;
    *)
      echo "github-mcp: unknown system $1" >&2
      return 1
      ;;
  esac
}

refresh_github_mcp() {
  local root file version current sys asset url hash
  root=$(update_repo_root)
  file=$root/home/github-mcp-pkg.nix
  version=$(github_latest_version github github-mcp-server)
  current=$(read_nix_string_assign "$file" version)
  echo "github-mcp: $version"
  if [[ $current == "$version" && ${UPDATE_FORCE:-} != 1 ]]; then
    echo "github-mcp: $version (unchanged)"
    return 0
  fi
  if update_dry_run; then
    echo "dry-run: $file: version = \"$version\""
    return 0
  fi
  for sys in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
    asset=$(github_mcp_asset "$sys")
    url="https://github.com/github/github-mcp-server/releases/download/v${version}/${asset}"
    hash=$(prefetch_url_hash "$url" nix32)
    replace_attr_sha256 "$file" "$sys" "$hash"
  done
  replace_nix_string_assign "$file" version "$version"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_github_mcp "$@"
fi
