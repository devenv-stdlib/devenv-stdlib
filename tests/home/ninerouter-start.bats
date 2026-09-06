#!/usr/bin/env bats
# Exercises home/ninerouter-start.sh password-hash persist. No live 9Router.

bats_require_minimum_version 1.5.0

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$REPO_DIR/home/ninerouter-start.sh"
  TMP=$(mktemp -d)
  export HOME="$TMP/home"
  export NINEROUTER_PYTHON="$TMP/bin/py"
  mkdir -p "$HOME/.9router/db" "$TMP/bin"
  printf '#!/bin/sh\nprintf "hashed\\n"\n' >"$NINEROUTER_PYTHON"
  chmod +x "$NINEROUTER_PYTHON"
}

teardown() {
  rm -rf "$TMP"
}

@test "persist is a no-op when the sqlite file is missing" {
  printf '#!/bin/sh\necho ran >>"%s"\n' "$TMP/docker.ran" >"$TMP/bin/docker"
  chmod +x "$TMP/bin/docker"
  run nine_router_persist_initial_password "$TMP/bin/docker" img "$HOME/.9router" secret
  [ "$status" -eq 0 ]
  [ ! -f "$TMP/docker.ran" ]
}

@test "persist is a no-op when the password is empty or 123456" {
  : >"$HOME/.9router/db/data.sqlite"
  printf '#!/bin/sh\necho ran >>"%s"\n' "$TMP/docker.ran" >"$TMP/bin/docker"
  chmod +x "$TMP/bin/docker"
  run nine_router_persist_initial_password "$TMP/bin/docker" img "$HOME/.9router" ""
  [ "$status" -eq 0 ]
  run nine_router_persist_initial_password "$TMP/bin/docker" img "$HOME/.9router" 123456
  [ "$status" -eq 0 ]
  [ ! -f "$TMP/docker.ran" ]
}

@test "start dry-run hops published traffic through an in-container loopback proxy" {
  printf '#!/bin/sh\nexit 0\n' >"$TMP/bin/docker"
  chmod +x "$TMP/bin/docker"
  export PATH="$TMP/bin:$PATH"
  export NINEROUTER_DRY_RUN=1
  export NINEROUTER_HOST_IP=192.0.2.1
  export NINEROUTER_LOOPBACK_PROXY="$REPO_DIR/home/ninerouter-loopback-proxy.js"
  unset INITIAL_PASSWORD
  run nine_router_start
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q -- '-p'
  printf '%s\n' "$output" | grep -q -- '127.0.0.1:20128:20128'
  printf '%s\n' "$output" | grep -q -- 'HOSTNAME=127.0.0.1'
  printf '%s\n' "$output" | grep -q -- 'PORT=20129'
  printf '%s\n' "$output" | grep -q -- 'NINEROUTER_PUBLISH_PORT=20128'
  printf '%s\n' "$output" | grep -q -- 'ninerouter-loopback-proxy.js'
  printf '%s\n' "$output" | grep -q -- 'node custom-server.js'
  if printf '%s\n' "$output" | grep -q -- 'HOSTNAME=0.0.0.0'; then
    echo "unexpected HOSTNAME=0.0.0.0" >&2
    return 1
  fi
}

@test "persist writes a host-computed hash via a one-shot container" {
  : >"$HOME/.9router/db/data.sqlite"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >"%s"\n' "$TMP/docker.args" >"$TMP/bin/docker"
  chmod +x "$TMP/bin/docker"
  run nine_router_persist_initial_password "$TMP/bin/docker" img:tag "$HOME/.9router" secret
  [ "$status" -eq 0 ]
  grep -q -- '--name 9router-persist-password' "$TMP/docker.args"
  grep -q -- '--entrypoint node' "$TMP/docker.args"
  grep -q -- '-e PASSWORD_HASH=hashed' "$TMP/docker.args"
  grep -q -- "$HOME/.9router:/app/data" "$TMP/docker.args"
  grep -q -- 'img:tag' "$TMP/docker.args"
}
