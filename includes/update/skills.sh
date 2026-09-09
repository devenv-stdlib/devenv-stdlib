#!/usr/bin/env bash
# Refresh vendored agent skills (.agents/skills, skills-lock.json) with the
# Vercel skills CLI (project-scope mise tool from modules/non-nix/catalog.json).
# Add or remove skills from the repo root with `skills add …` / `skills remove`;
# this only pulls newer upstream copies. Review the diff before committing.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

refresh_skills() {
  local root
  root=$(update_repo_root)
  if [[ ! -f $root/skills-lock.json ]]; then
    echo "skills: no skills-lock.json in $root" >&2
    return 1
  fi
  if update_dry_run; then
    echo "dry-run: skills update -y -p (in $root)"
    return 0
  fi
  if ! command -v skills >/dev/null 2>&1; then
    echo "skills: install the project mise tool (devenv shell / mise install)" >&2
    return 1
  fi
  (cd "$root" && skills update -y -p)
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_skills "$@"
fi
