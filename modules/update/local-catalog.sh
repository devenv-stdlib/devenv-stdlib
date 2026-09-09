#!/usr/bin/env bash
# Consumer: bump modules/non-nix/catalog.local.toml and install tools.
# Nix when promotable (after devenv update); otherwise mise install @pin.
# Docker images: docker pull. VS Code extensions: pin only (Marketplace via HM).
set -euo pipefail

root=${DEVENV_ROOT:-${UPDATE_ROOT:-}}
if [[ -z $root ]]; then
  echo "local-catalog: set DEVENV_ROOT" >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$root/modules/update/pin-lib.sh"

ubi_owner_repo() {
  local mise=$1 rest
  rest=${mise#ubi:}
  printf '%s %s\n' "${rest%%/*}" "$(cut -d/ -f2 <<<"$rest")"
}

pipx_pkg() {
  local p=${1#pipx:}
  printf '%s\n' "${p%%\[*}"
}

npm_pkg() {
  printf '%s\n' "${1#npm:}"
}

bump_cli_at() {
  local catalog=$1 name=$2 mise=$3 current latest owner repo
  current=$(catalog_read_pin "$name" "$catalog")
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
      echo "local-catalog: unsupported mise backend for $name ($mise)" >&2
      return 1
      ;;
  esac
  echo "local-catalog: $name → $latest"
  if [[ $current == "$latest" && ${UPDATE_FORCE:-} != 1 ]]; then
    echo "local-catalog: $name unchanged"
    return 0
  fi
  catalog_set_pin "$name" "$latest" "$catalog"
}

bump_docker_at() {
  local catalog=$1 name=$2 image=$3 current tag
  current=$(catalog_read_pin "$name" "$catalog")
  if ! tag=$(docker_hub_latest_semver "$image" 2>/dev/null); then
    echo "local-catalog: no semver for $image; leaving $name at $current" >&2
    return 0
  fi
  echo "local-catalog: $name → $tag"
  if [[ $current == "$tag" && ${UPDATE_FORCE:-} != 1 ]]; then
    echo "local-catalog: $name unchanged"
    return 0
  fi
  catalog_set_pin "$name" "$tag" "$catalog"
}

install_cli() {
  local name=$1 mise=$2 pin=$3 via
  via=$(catalog_tool_via "$name")
  if [[ $via == nix ]]; then
    echo "local-catalog: $name via nixpkgs (skip mise)"
    return 0
  fi
  if [[ -z $mise ]]; then
    echo "local-catalog: $name has no mise id and is not Nix-promotable" >&2
    return 1
  fi
  if update_dry_run; then
    echo "dry-run: mise install ${mise}@${pin}"
    return 0
  fi
  if ! command -v mise >/dev/null 2>&1; then
    echo "local-catalog: mise not on PATH; enter devenv shell or home-switch" >&2
    return 1
  fi
  echo "local-catalog: mise install ${mise}@${pin}"
  mise install "${mise}@${pin}"
}

install_docker() {
  local image=$1 pin=$2 ref
  ref=${image}:${pin}
  if update_dry_run; then
    echo "dry-run: docker pull $ref"
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    echo "local-catalog: docker pull $ref"
    docker pull "$ref" || true
  else
    echo "local-catalog: docker not on PATH; skip $ref" >&2
  fi
}

refresh_local_catalog() {
  local catalog
  catalog=$(catalog_local_path)
  if [[ ! -f $catalog ]]; then
    echo "local-catalog: no $catalog (copy catalog.local.toml.example to modules/non-nix/catalog.local.toml)"
    return 0
  fi

  echo "local-catalog: refreshing $catalog"
  while IFS=$'\t' read -r name kind mise image publisher extension; do
    case $kind in
      cli)
        bump_cli_at "$catalog" "$name" "$mise"
        pin=$(catalog_read_pin "$name" "$catalog")
        install_cli "$name" "$mise" "$pin"
        ;;
      docker-image)
        bump_docker_at "$catalog" "$name" "$image"
        pin=$(catalog_read_pin "$name" "$catalog")
        install_docker "$image" "$pin"
        ;;
      vscode-extension)
        echo "local-catalog: $name vscode pin left for home-switch / Marketplace ($publisher.$extension)"
        ;;
      *)
        echo "local-catalog: unknown kind $kind for $name" >&2
        return 1
        ;;
    esac
  done < <(catalog_list_tools "$catalog")
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_local_catalog "$@"
fi
