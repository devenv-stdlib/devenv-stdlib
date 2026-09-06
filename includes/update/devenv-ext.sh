#!/usr/bin/env bash
# Refresh the devenv VS Marketplace extension in home/vscode-ext-lib.nix.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

refresh_devenv_ext() {
  local root file version current url hash
  root=$(update_repo_root)
  file=$root/home/vscode-ext-lib.nix
  version=$(vs_marketplace_latest datakurre devenv)
  current=$(read_nix_string_assign "$file" version)
  echo "datakurre.devenv: $version"
  if [[ $current == "$version" && ${UPDATE_FORCE:-} != 1 ]]; then
    echo "datakurre.devenv: $version (unchanged)"
    return 0
  fi
  if update_dry_run; then
    echo "dry-run: $file: version = \"$version\""
    return 0
  fi
  url=$(vs_marketplace_vsix_url datakurre devenv "$version")
  hash=$(prefetch_url_hash "$url" nix32)
  replace_nix_string_assign "$file" sha256 "$hash"
  replace_nix_string_assign "$file" version "$version"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_devenv_ext "$@"
fi
