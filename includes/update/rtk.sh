#!/usr/bin/env bash
# Refresh home/rtk-pkg.nix from the latest GitHub release.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

rtk_asset() {
  case $1 in
    x86_64-linux) printf '%s\n' rtk-x86_64-unknown-linux-musl.tar.gz ;;
    aarch64-linux) printf '%s\n' rtk-aarch64-unknown-linux-gnu.tar.gz ;;
    x86_64-darwin) printf '%s\n' rtk-x86_64-apple-darwin.tar.gz ;;
    aarch64-darwin) printf '%s\n' rtk-aarch64-apple-darwin.tar.gz ;;
    *)
      echo "rtk: unknown system $1" >&2
      return 1
      ;;
  esac
}

refresh_rtk() {
  local root file version current sys asset url hash
  root=$(update_repo_root)
  file=$root/home/rtk-pkg.nix
  version=$(github_latest_version rtk-ai rtk)
  current=$(read_nix_string_assign "$file" version)
  echo "rtk: $version"
  if [[ $current == "$version" && ${UPDATE_FORCE:-} != 1 ]]; then
    echo "rtk: $version (unchanged)"
    return 0
  fi
  if update_dry_run; then
    echo "dry-run: $file: version = \"$version\""
    return 0
  fi
  for sys in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
    asset=$(rtk_asset "$sys")
    url="https://github.com/rtk-ai/rtk/releases/download/v${version}/${asset}"
    hash=$(prefetch_url_hash "$url" hex)
    replace_attr_sha256 "$file" "$sys" "$hash"
  done
  replace_nix_string_assign "$file" version "$version"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_rtk "$@"
fi
