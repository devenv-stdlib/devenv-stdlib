#!/usr/bin/env bats
# End-to-end tests for hooks/reference-transaction: creating a tag must run the
# test suite and must be aborted when the suite fails. Each test drives a real
# `git tag` in a throwaway repository with a stubbed `bats` on PATH, so these
# tests verify the git wiring rather than the suite they would normally run.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  HOOK="$REPO_DIR/hooks/reference-transaction"
  STUB_DIR="$BATS_TEST_TMPDIR/stub-bin"
  MARKER="$BATS_TEST_TMPDIR/bats-ran"
  WORK="$BATS_TEST_TMPDIR/repo"

  mkdir -p "$STUB_DIR" "$WORK/tests"
  cd "$WORK" || return 1
  git init -q -b main .
  git config user.email tester@example.com
  git config user.name Tester
  install -m 755 "$HOOK" "$(git rev-parse --git-path hooks)/reference-transaction"

  echo content >file.txt
  git add file.txt
  git commit -qm "initial commit"
}

# Stand in for the real suite: record the invocation and report `code`.
stub_bats() {
  {
    printf '#!/usr/bin/env bash\n'
    printf 'touch %q\n' "$MARKER"
    printf 'echo "suite invoked with: $*"\n'
    printf 'exit %s\n' "$1"
  } >"$STUB_DIR/bats"
  chmod +x "$STUB_DIR/bats"
}

git_with_stubs() {
  run env PATH="$STUB_DIR:$PATH" git "$@"
}

tag_exists() {
  git rev-parse -q --verify "refs/tags/$1" >/dev/null
}

@test "reference-transaction hook passes shellcheck" {
  command -v shellcheck >/dev/null || skip "shellcheck not installed"
  run shellcheck "$HOOK"
  [ "$status" -eq 0 ]
}

@test "tagging runs the test suite" {
  stub_bats 0
  git_with_stubs tag v1.0.0
  [ "$status" -eq 0 ]
  [ -e "$MARKER" ]
  [[ $output == *"running the setup.sh test suite before creating tag v1.0.0"* ]]
  tag_exists v1.0.0
}

@test "a failing suite aborts tag creation" {
  stub_bats 1
  git_with_stubs tag v1.0.1
  [ "$status" -ne 0 ]
  [ -e "$MARKER" ]
  [[ $output == *"refusing to create tag v1.0.1"* ]]
  run tag_exists v1.0.1
  [ "$status" -ne 0 ]
}

@test "a failing suite aborts annotated tag creation" {
  stub_bats 1
  git_with_stubs tag -a v1.0.2 -m "release"
  [ "$status" -ne 0 ]
  run tag_exists v1.0.2
  [ "$status" -ne 0 ]
}

@test "commits are not gated on the test suite" {
  stub_bats 1
  echo more >>file.txt
  git add file.txt
  git_with_stubs commit -qm "second commit"
  [ "$status" -eq 0 ]
  [ ! -e "$MARKER" ]
}

@test "deleting a tag does not run the test suite" {
  stub_bats 0
  env PATH="$STUB_DIR:$PATH" git tag v1.0.3
  rm -f "$MARKER"
  stub_bats 1
  git_with_stubs tag -d v1.0.3
  [ "$status" -eq 0 ]
  [ ! -e "$MARKER" ]
}

@test "force-moving a tag is gated on the test suite" {
  stub_bats 0
  env PATH="$STUB_DIR:$PATH" git tag v1.0.7
  stub_bats 1
  echo more >>file.txt
  git add file.txt
  git commit -qm "another commit"
  git_with_stubs tag -f v1.0.7
  [ "$status" -ne 0 ]
  [[ $output == *"refusing to create tag v1.0.7"* ]]
}

@test "fetched tags are not gated on the test suite" {
  stub_bats 1
  run env PATH="$STUB_DIR:$PATH" GIT_REFLOG_ACTION=fetch git tag v1.0.4
  [ "$status" -eq 0 ]
  [ ! -e "$MARKER" ]
}

@test "DEVENV_SKIP_TAG_TESTS bypasses the suite" {
  stub_bats 1
  run env PATH="$STUB_DIR:$PATH" DEVENV_SKIP_TAG_TESTS=1 git tag v1.0.5
  [ "$status" -eq 0 ]
  [ ! -e "$MARKER" ]
  tag_exists v1.0.5
}

@test "CI environment skips the test suite" {
  stub_bats 1
  run env PATH="$STUB_DIR:$PATH" CI=true git tag v1.0.8
  [ "$status" -eq 0 ]
  [ ! -e "$MARKER" ]
  tag_exists v1.0.8
}

@test "the hook reports a real failing suite through git tag" {
  command -v bats >/dev/null || skip "bats not installed"
  cat >"$WORK/tests/broken.bats" <<'BATS'
@test "intentionally failing test" {
  false
}
BATS
  run env -u BATS_ROOT -u BATS_RUN_TMPDIR git tag v1.0.6
  [ "$status" -ne 0 ]
  [[ $output == *"intentionally failing test"* ]]
  run tag_exists v1.0.6
  [ "$status" -ne 0 ]
}
