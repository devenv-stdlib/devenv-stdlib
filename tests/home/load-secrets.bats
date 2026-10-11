#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# ^ SC2030/SC2031: each @test looks like a subshell, so PATH exports are
# reported as leaking or getting lost; they are deliberately per-test.
# Exercises home/load-secrets.sh. No live SecretSpec providers.

bats_require_minimum_version 1.5.0

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$REPO_DIR/home/load-secrets.sh"
  TMP=$(mktemp -d)
  mkdir -p "$TMP/bin" "$TMP/proj"
  printf '[project]\nname = "t"\n' >"$TMP/proj/secretspec.toml"
}

teardown() {
  rm -rf "$TMP"
}

@test "secretspec export wins over .env" {
  printf 'BRAVE_API_KEY=from-env\n' >"$TMP/proj/.env"
  cat >"$TMP/bin/secretspec" <<'EOF'
#!/usr/bin/env bash
echo "export BRAVE_API_KEY='from-spec'"
EOF
  chmod +x "$TMP/bin/secretspec"
  PATH="$TMP/bin:$PATH"
  unset BRAVE_API_KEY
  home_load_secrets "$TMP/proj"
  [ "$BRAVE_API_KEY" = "from-spec" ]
}

@test "falls back to .env when secretspec export fails" {
  printf 'BRAVE_API_KEY=from-env\n' >"$TMP/proj/.env"
  cat >"$TMP/bin/secretspec" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$TMP/bin/secretspec"
  PATH="$TMP/bin:$PATH"
  unset BRAVE_API_KEY
  home_load_secrets "$TMP/proj"
  [ "$BRAVE_API_KEY" = "from-env" ]
}

@test "sources .env when secretspec is not on PATH" {
  printf 'BRAVE_API_KEY=from-env\n' >"$TMP/proj/.env"
  PATH="/usr/bin:/bin"
  unset BRAVE_API_KEY
  home_load_secrets "$TMP/proj"
  [ "$BRAVE_API_KEY" = "from-env" ]
}
