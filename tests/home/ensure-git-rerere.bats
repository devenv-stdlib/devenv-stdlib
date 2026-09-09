#!/usr/bin/env bats
# Exercises home/ensure-git-rerere.sh against a throwaway git repo.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TMP=$(mktemp -d)
  cd "$TMP" || exit 1
  git init -q
  git config user.email "test@example.com"
  git config user.name "test"
  # shellcheck disable=SC1091
  source "$REPO_DIR/home/ensure-git-rerere.sh"
}

teardown() {
  rm -rf "$TMP"
}

@test "ensure_git_rerere sets local rerere.enabled and rerere.autoupdate" {
  ensure_git_rerere
  [ "$(git config --local --get rerere.enabled)" = "true" ]
  [ "$(git config --local --get rerere.autoupdate)" = "true" ]
}

@test "ensure_git_rerere is idempotent" {
  ensure_git_rerere
  ensure_git_rerere
  [ "$(git config --local --get rerere.enabled)" = "true" ]
  [ "$(git config --local --get rerere.autoupdate)" = "true" ]
}
