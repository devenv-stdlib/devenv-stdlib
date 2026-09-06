#!/usr/bin/env bash
# Refresh decolua/9router tag in home/ninerouter-start.sh from Docker Hub.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

refresh_ninerouter() {
  local root file tag image
  root=$(update_repo_root)
  file=$root/home/ninerouter-start.sh
  tag=$(docker_hub_latest_semver decolua/9router)
  image=decolua/9router:$tag
  echo "9router: $image"
  replace_ninerouter_image "$file" "$image"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_ninerouter "$@"
fi
