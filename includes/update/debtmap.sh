#!/usr/bin/env bash
# Refresh modules/debtmap-pkg.nix from the latest GitHub release.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

debtmap_asset() {
  case $1 in
    x86_64-linux) printf '%s\n' debtmap-x86_64-unknown-linux-musl.tar.gz ;;
    x86_64-darwin) printf '%s\n' debtmap-x86_64-apple-darwin.tar.gz ;;
    aarch64-darwin) printf '%s\n' debtmap-aarch64-apple-darwin.tar.gz ;;
    *)
      echo "debtmap: unknown system $1" >&2
      return 1
      ;;
  esac
}

refresh_debtmap() {
  local root file version current sys asset url hash
  root=$(update_repo_root)
  file=$root/modules/debtmap-pkg.nix
  version=$(github_latest_version iepathos debtmap)
  current=$(read_nix_string_assign "$file" version)
  echo "debtmap: $version"
  if [[ $current == "$version" && ${UPDATE_FORCE:-} != 1 ]]; then
    echo "debtmap: $version (unchanged)"
    return 0
  fi
  if update_dry_run; then
    echo "dry-run: $file: version = \"$version\""
    return 0
  fi
  for sys in x86_64-linux x86_64-darwin aarch64-darwin; do
    asset=$(debtmap_asset "$sys")
    url="https://github.com/iepathos/debtmap/releases/download/${version}/${asset}"
    hash=$(prefetch_url_hash "$url" hex)
    replace_attr_sha256 "$file" "$sys" "$hash"
  done
  replace_nix_string_assign "$file" version "$version"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_debtmap "$@"
fi
