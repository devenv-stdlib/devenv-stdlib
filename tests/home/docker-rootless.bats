#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# ^ SC2030/SC2031: each @test looks like a subshell, so DOCKER_HOST exports
# are reported as leaking or getting lost; they are deliberately per-test.
# Defaults DOCKER_HOST to the rootless Engine socket. No live dockerd.

bats_require_minimum_version 1.5.0

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$REPO_DIR/home/docker-rootless.sh"
  unset DOCKER_HOST CI GITHUB_ACTIONS
  export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run"
}

@test "docker_rootless_env sets DOCKER_HOST to the user socket" {
  docker_rootless_env
  [ "$DOCKER_HOST" = "unix://$XDG_RUNTIME_DIR/docker.sock" ]
}

@test "docker_rootless_env keeps an existing DOCKER_HOST" {
  export DOCKER_HOST=unix:///var/run/docker.sock
  docker_rootless_env
  [ "$DOCKER_HOST" = "unix:///var/run/docker.sock" ]
}

@test "docker_rootless_env is a no-op under CI" {
  export CI=true
  docker_rootless_env
  [ -z "${DOCKER_HOST:-}" ]
}

@test "docker_engine_sock strips unix:// after env" {
  docker_rootless_env
  [ "$(docker_engine_sock)" = "$XDG_RUNTIME_DIR/docker.sock" ]
}

@test "docker_engine_sock fails for a tcp DOCKER_HOST" {
  export DOCKER_HOST=tcp://127.0.0.1:2375
  run docker_engine_sock
  [ "$status" -ne 0 ]
}
