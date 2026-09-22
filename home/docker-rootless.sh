#!/usr/bin/env bash
# Default docker(1), act, and the Docker MCP to the rootless Engine socket.
# CI keeps the runner daemon (usually rootful). Override with DOCKER_HOST.
# shellcheck disable=SC2034

docker_rootless_sock() {
  printf '%s/docker.sock' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
}

docker_rootless_host() {
  printf 'unix://%s' "$(docker_rootless_sock)"
}

docker_rootless_env() {
  if [[ -n ${DOCKER_HOST:-} ]]; then
    return 0
  fi
  if [[ -n ${CI:-} || -n ${GITHUB_ACTIONS:-} ]]; then
    return 0
  fi
  export DOCKER_HOST
  DOCKER_HOST=$(docker_rootless_host)
}

# Unix socket to bind-mount into mcp/docker. Fails for tcp:// DOCKER_HOST.
docker_engine_sock() {
  docker_rootless_env
  local host=${DOCKER_HOST:-}
  if [[ $host == unix://* ]]; then
    printf '%s' "${host#unix://}"
    return 0
  fi
  if [[ -n $host ]]; then
    return 1
  fi
  docker_rootless_sock
}
