#!/usr/bin/env bash
# Template: refresh shipped non-Nix pins in includes/update/.
# Consumer: devenv update, then catalog.local.toml tools, then update.local.sh.
set -euo pipefail

root=${DEVENV_ROOT:-}
if [[ -z $root ]]; then
  echo "update: DEVENV_ROOT is not set" >&2
  exit 1
fi

refresh_dir=$root/includes/update

if [[ -d $refresh_dir ]]; then
  echo "update: template mode ($refresh_dir); not running devenv update"
  shopt -s nullglob
  scripts=("$refresh_dir"/*.sh)
  if [[ ${#scripts[@]} -gt 0 ]]; then
    mapfile -t scripts < <(printf '%s\n' "${scripts[@]}" | LC_ALL=C sort)
  fi
  ran=0
  for script in "${scripts[@]}"; do
    [[ -f $script ]] || continue
    [[ $(basename "$script") == lib.sh ]] && continue
    echo "update: $(basename "$script")"
    bash "$script"
    ran=1
  done
  if [[ $ran -eq 0 ]]; then
    echo "update: no pin refreshers"
  fi
  exit 0
fi

echo "update: consumer mode — refreshing flake inputs"
devenv update

local_catalog=$root/modules/update/local-catalog.sh
if [[ -x $local_catalog || -f $local_catalog ]]; then
  echo "update: refreshing modules/non-nix/catalog.local.toml"
  bash "$local_catalog"
fi

local_hook=$root/update.local.sh
if [[ -x $local_hook ]]; then
  echo "update: running update.local.sh"
  "$local_hook"
elif [[ -e $local_hook ]]; then
  echo "update: $local_hook exists but is not executable; skipping" >&2
fi

cat <<'EOF'
Template-shipped tools (RTK, Serena, Headroom, 9Router, MCP pins, debtmap, …)
move only via copier update. Team tools live in modules/non-nix/catalog.local.toml
and are refreshed by this `update` (Nix when promotable, else mise).
EOF
