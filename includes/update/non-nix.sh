#!/usr/bin/env bash
# Refresh modules/non-nix/catalog.json pins (and a few install-side hashes).
# CLI tools install via mise (or Nix when promoted); images via docker pull;
# devenv VS Code extension still uses vscode-ext-lib.nix for the VSIX hash.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

ubi_owner_repo() {
  # ubi:owner/repo[/…] → owner repo
  local mise=$1 rest
  rest=${mise#ubi:}
  printf '%s %s\n' "${rest%%/*}" "$(cut -d/ -f2 <<<"$rest")"
}

pipx_pkg() {
  local p=${1#pipx:}
  # Drop optional extras: headroom-ai[mcp] → headroom-ai
  printf '%s\n' "${p%%\[*}"
}

npm_pkg() {
  printf '%s\n' "${1#npm:}"
}

bump_cli() {
  local name=$1 mise=$2 current latest owner repo
  current=$(catalog_read_pin "$name")
  case $mise in
    ubi:*)
      read -r owner repo < <(ubi_owner_repo "$mise")
      latest=$(github_latest_version "$owner" "$repo")
      ;;
    pipx:*)
      latest=$(pypi_latest "$(pipx_pkg "$mise")")
      ;;
    npm:*)
      latest=$(npm_latest "$(npm_pkg "$mise")")
      ;;
    *)
      echo "non-nix: unsupported mise backend for $name ($mise)" >&2
      return 1
      ;;
  esac
  echo "$name: $latest"
  if [[ $current == "$latest" && ${UPDATE_FORCE:-} != 1 ]]; then
    echo "$name: $latest (unchanged)"
    return 0
  fi
  catalog_set_pin "$name" "$latest"
}

bump_docker() {
  local name=$1 image=$2 current tag
  current=$(catalog_read_pin "$name")
  if ! tag=$(docker_hub_latest_semver "$image" 2>/dev/null); then
    echo "non-nix: no semver tags for $image; leaving $name at $current" >&2
    return 0
  fi
  echo "$name: $tag"
  if [[ $current == "$tag" && ${UPDATE_FORCE:-} != 1 ]]; then
    echo "$name: $tag (unchanged)"
    return 0
  fi
  catalog_set_pin "$name" "$tag"
  if [[ $name == ninerouter ]]; then
    replace_ninerouter_image "$(update_repo_root)/home/ninerouter-start.sh" "${image}:${tag}"
  fi
}

bump_vscode() {
  local name=$1 publisher=$2 extension=$3 current version url hash root
  root=$(update_repo_root)
  current=$(catalog_read_pin "$name")
  version=$(vs_marketplace_latest "$publisher" "$extension")
  echo "$publisher.$extension: $version"
  if [[ $current == "$version" && ${UPDATE_FORCE:-} != 1 ]]; then
    echo "$publisher.$extension: $version (unchanged)"
    return 0
  fi
  if update_dry_run; then
    echo "dry-run: catalog + vscode-ext-lib: version = \"$version\""
    return 0
  fi
  url=$(vs_marketplace_vsix_url "$publisher" "$extension" "$version")
  hash=$(prefetch_url_hash "$url" nix32)
  catalog_set_pin "$name" "$version"
  replace_nix_string_assign "$root/home/vscode-ext-lib.nix" sha256 "$hash"
}

print_promotable() {
  local catalog
  catalog=$(catalog_path)
  echo "non-nix: CLI entries with nixAttr (promote when nixpkgs is new enough + homepage matches):"
  jq -r '.[] | select(.kind == "cli" and .nixAttr != null) | "  CANDIDATE \(.name) pin=\(.pin)"' "$catalog"
}

refresh_non_nix() {
  local root catalog
  root=$(update_repo_root)
  catalog=$root/modules/non-nix/catalog.json
  if [[ ! -f $catalog ]]; then
    echo "non-nix: missing $catalog" >&2
    return 1
  fi

  while IFS=$'\t' read -r name kind mise image publisher extension; do
    case $kind in
      cli)
        bump_cli "$name" "$mise"
        ;;
      docker-image)
        bump_docker "$name" "$image"
        ;;
      vscode-extension)
        bump_vscode "$name" "$publisher" "$extension"
        ;;
      *)
        echo "non-nix: unknown kind $kind for $name" >&2
        return 1
        ;;
    esac
  done < <(
    jq -r '.[] | [.name, .kind, (.mise // ""), (.image // ""), (.publisher // ""), (.extension // "")] | @tsv' \
      "$catalog"
  )

  print_promotable
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_non_nix "$@"
fi
