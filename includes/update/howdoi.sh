#!/usr/bin/env bash
# Refresh home/howdoi.nix from the latest GitHub release.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

refresh_howdoi() {
  local root file version current url hash
  root=$(update_repo_root)
  file=$root/home/howdoi.nix
  version=$(github_latest_version gleitz howdoi)
  current=$(read_nix_string_assign "$file" version)
  echo "howdoi: $version"
  if [[ $current == "$version" && ${UPDATE_FORCE:-} != 1 ]]; then
    echo "howdoi: $version (unchanged)"
    return 0
  fi
  if update_dry_run; then
    echo "dry-run: $file: version = \"$version\""
    return 0
  fi
  url="https://github.com/gleitz/howdoi/archive/v${version}.tar.gz"
  hash=$(prefetch_url_hash "$url" sri unpack)
  replace_nix_string_assign "$file" hash "$hash"
  replace_nix_string_assign "$file" version "$version"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_howdoi "$@"
fi
