#!/usr/bin/env bash
# Idempotently enable git rerere for this repository (local config only).
# Sourced by setup.sh and devenv enterShell.
# shellcheck disable=SC2034

ensure_git_rerere() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    return 0
  fi
  git config --local rerere.enabled true
  git config --local rerere.autoupdate true
}
