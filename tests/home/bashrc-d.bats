#!/usr/bin/env bats
# Exercises home/ensure-bashrc-d.sh. Does not run home-manager switch.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$REPO_DIR/home/ensure-bashrc-d.sh"
  TMP=$(mktemp -d)
  SKEL="$TMP/skel.bashrc"
  cat >"$SKEL" <<'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.
case $- in
    *i*) ;;
      *) return;;
esac
HISTSIZE=1000
EOF
}

teardown() {
  rm -rf "$TMP"
}

@test "copies skel and appends the .bashrc.d hook when bashrc is missing" {
  ensure_bashrc_d "$TMP/.bashrc" "$SKEL"
  grep -q 'HISTSIZE=1000' "$TMP/.bashrc"
  grep -qF '# devenv4monorepo: .bashrc.d' "$TMP/.bashrc"
  grep -q '.bashrc.d/' "$TMP/.bashrc"
}

@test "appends the hook to an existing Ubuntu bashrc once" {
  cp "$SKEL" "$TMP/.bashrc"
  ensure_bashrc_d "$TMP/.bashrc" "$SKEL"
  ensure_bashrc_d "$TMP/.bashrc" "$SKEL"
  [ "$(grep -cF '# devenv4monorepo: .bashrc.d' "$TMP/.bashrc")" -eq 1 ]
  grep -q 'HISTSIZE=1000' "$TMP/.bashrc"
}

@test "replaces a Nix-store symlink with skel plus the hook" {
  store_file=$(find /nix/store -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)
  if [ -z "$store_file" ]; then
    skip "/nix/store not available"
  fi
  ln -s "$store_file" "$TMP/.bashrc"
  ensure_bashrc_d "$TMP/.bashrc" "$SKEL"
  [ ! -L "$TMP/.bashrc" ]
  grep -q 'HISTSIZE=1000' "$TMP/.bashrc"
  grep -qF '# devenv4monorepo: .bashrc.d' "$TMP/.bashrc"
}

@test "writes a minimal bashrc when skel is absent" {
  ensure_bashrc_d "$TMP/.bashrc" "$TMP/missing-skel"
  grep -q 'case $-' "$TMP/.bashrc"
  grep -qF '# devenv4monorepo: .bashrc.d' "$TMP/.bashrc"
}
