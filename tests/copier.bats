#!/usr/bin/env bats
# Copier copy/update for this template. Does not evaluate devenv or touch
# the real /nix. Builds a throwaway git template from the working tree so
# uncommitted copier.yml is included.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  command -v copier >/dev/null || skip "copier not installed"
  command -v git >/dev/null || skip "git not installed"

  SRC="$BATS_TEST_TMPDIR/template"
  DEST="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$SRC" "$DEST"

  while IFS= read -r -d '' f; do
    mkdir -p "$SRC/$(dirname "$f")"
    cp -a "$REPO_DIR/$f" "$SRC/$f"
  done < <(git -C "$REPO_DIR" ls-files -co --exclude-standard -z)

  git -C "$SRC" init -q -b master
  git -C "$SRC" config user.email tester@example.com
  git -C "$SRC" config user.name Tester
  git -C "$SRC" add -A
  git -C "$SRC" commit -qm "template"
  git -C "$SRC" tag v0.0.0
}

copy_template() {
  local dest=${1:-$DEST}
  shift || true
  copier copy --defaults --quiet --vcs-ref v0.0.0 "$@" "$SRC" "$dest"
}

init_dest_git() {
  local dest=${1:-$DEST}
  git -C "$dest" init -q -b main
  git -C "$dest" config user.email tester@example.com
  git -C "$dest" config user.name Tester
  git -C "$dest" add -A
  git -C "$dest" commit -qm "apply template"
}

@test "copier copy writes devenv files and answers, excludes template metadata" {
  run copy_template
  [ "$status" -eq 0 ]

  [ -f "$DEST/devenv.nix" ]
  [ -f "$DEST/devenv.yaml" ]
  [ -f "$DEST/devenv.lock" ]
  [ -f "$DEST/setup.sh" ]
  [ -f "$DEST/home.nix" ]
  [ -f "$DEST/modules/devenv.nix" ]
  [ -f "$DEST/modules/toolchain-catalog.json" ]
  [ -f "$DEST/README.md" ]
  [ -f "$DEST/.copier-answers.yml" ]
  grep -q '_src_path:' "$DEST/.copier-answers.yml"
  grep -q '_commit:' "$DEST/.copier-answers.yml"
  grep -q 'project_name:' "$DEST/.copier-answers.yml"

  [ ! -e "$DEST/copier.yml" ]
  [ ! -e "$DEST/copier.yaml" ]
  [ ! -e "$DEST/tests/copier.bats" ]
  [ ! -e "$DEST/home.local.nix" ]
  [ ! -e "$DEST/{{_copier_conf.answers_file}}.jinja" ]
  [ ! -e "$DEST/devenv.local.nix.jinja" ]
  [ ! -e "$DEST/.gitignore.jinja" ]
  [ ! -e "$DEST/includes" ]
}

@test "copier copy writes devenv.local.nix from default answers" {
  run copy_template
  [ "$status" -eq 0 ]

  [ -f "$DEST/devenv.local.nix" ]
  grep -q 'name = "proj";' "$DEST/devenv.local.nix"
  run ! grep -q 'languages.rust.enable' "$DEST/devenv.local.nix"
  run ! grep -q 'languages.python' "$DEST/devenv.local.nix"
  run ! grep -q '^devenv.local.nix$' "$DEST/.gitignore"
}

@test "copier copy asks languages and writes rust plus python into devenv.local.nix" {
  run copy_template "$DEST" -d 'project_name=shop' -d 'languages=["rust", "python"]'
  [ "$status" -eq 0 ]

  grep -q 'name = "shop";' "$DEST/devenv.local.nix"
  grep -q 'languages.rust.enable = true;' "$DEST/devenv.local.nix"
  rust_max=$(sed -n 's/^rust: "\(.*\)"/\1/p' "$REPO_DIR/includes/toolchain-latest.yml")
  python_max=$(sed -n 's/^python: "\(.*\)"/\1/p' "$REPO_DIR/includes/toolchain-latest.yml")
  grep -q 'supported.rust.min = "1.80.0";' "$DEST/devenv.local.nix"
  grep -q "supported.rust.max = \"$rust_max\";" "$DEST/devenv.local.nix"
  grep -q 'languages.python' "$DEST/devenv.local.nix"
  grep -q 'supported.python.min = "3.12";' "$DEST/devenv.local.nix"
  grep -q "supported.python.max = \"$python_max\";" "$DEST/devenv.local.nix"
  grep -q 'pythonTypeChecker = "pyright";' "$DEST/devenv.local.nix"
  run ! grep -q 'languages.typescript.enable' "$DEST/devenv.local.nix"
  grep -q 'project_name: shop' "$DEST/.copier-answers.yml"
}

@test "copier copy leaves an existing README in place" {
  printf 'keep-readme\n' >"$DEST/README.md"

  run copy_template
  [ "$status" -eq 0 ]

  grep -qx 'keep-readme' "$DEST/README.md"
  [ -f "$DEST/devenv.nix" ]
  [ -f "$DEST/devenv.local.nix" ]
  [ -f "$DEST/.copier-answers.yml" ]
}

@test "copier update applies a newer template tag" {
  run copy_template
  [ "$status" -eq 0 ]
  init_dest_git

  printf '\n# copier-template-probe\n' >>"$SRC/devenv.nix"
  git -C "$SRC" add devenv.nix
  git -C "$SRC" commit -qm "feat: probe update"
  git -C "$SRC" tag v0.0.1

  run copier update --defaults --quiet --vcs-ref v0.0.1 "$DEST"
  [ "$status" -eq 0 ]
  grep -q 'copier-template-probe' "$DEST/devenv.nix"
  grep -q '_commit:' "$DEST/.copier-answers.yml"
}
