#!/usr/bin/env bash
# Refresh vendored agent skills (.agents/skills, skills-lock.json) with the
# Vercel skills CLI. Add or remove skills from the repo root with
# `npx skills add <owner/repo> --skill <name> -a cursor -y` / `npx skills remove`;
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
    echo "dry-run: npx skills update -y -p (in $root)"
    return 0
  fi
  (cd "$root" && npx -y skills@latest update -y -p)
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  refresh_skills "$@"
fi
