#!/usr/bin/env bash
# Publish 9Router on host loopback; reach Headroom via host.docker.internal.
# Rootless Docker is the default (do not use --network host).
# Sourced by tests; executed from the ninerouter user unit.
# shellcheck disable=SC1090

# The image has better-sqlite3 but not bcryptjs. Hash on the host, write
# the hash as container root. Leave a non-123456 hash alone.
nine_router_hash_password() {
  local password=$1
  local py=${NINEROUTER_PYTHON:-python3}
  INITIAL_PASSWORD=$password "$py" -c '
import bcrypt, os
print(bcrypt.hashpw(os.environ["INITIAL_PASSWORD"].encode(), bcrypt.gensalt(rounds=10)).decode())
'
}

nine_router_persist_initial_password() {
  local docker=$1
  local image=$2
  local data_dir=${3:-$HOME/.9router}
  local password=$4
  local hash
  if [[ ! -f $data_dir/db/data.sqlite || -z $password || $password == 123456 ]]; then
    return 0
  fi
  hash=$(nine_router_hash_password "$password") || return 1
  "$docker" run --rm --name 9router-persist-password --entrypoint node \
    -e "PASSWORD_HASH=$hash" \
    -v "$data_dir:/app/data" \
    -w /app \
    "$image" \
    -e '
const Database = require("better-sqlite3");
const hash = process.env.PASSWORD_HASH || "";
if (!hash) process.exit(0);
const db = new Database("/app/data/db/data.sqlite");
const row = db.prepare("SELECT id, data FROM settings").get();
const id = row && row.id != null ? row.id : 1;
const data = row ? JSON.parse(row.data) : {};
if (data.password) {
  db.close();
  process.exit(0);
}
data.password = hash;
if (row) {
  db.prepare("UPDATE settings SET data = ? WHERE id = ?").run(JSON.stringify(data), id);
} else {
  db.prepare("INSERT INTO settings (id, data) VALUES (?, ?)").run(id, JSON.stringify(data));
}
db.close();
'
}

nine_router_start() {
  set -euo pipefail

  local _docker_rootless_sh docker image port app_port proxy_js headroom_url
  local host_ip ip_bin cand passfile extra_e run

  _docker_rootless_sh=${DOCKER_ROOTLESS_SH:-}
  if [[ -z $_docker_rootless_sh ]]; then
    _docker_rootless_sh="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/docker-rootless.sh"
  fi
  if [[ -f $_docker_rootless_sh ]]; then
    # shellcheck disable=SC1090
    . "$_docker_rootless_sh"
    docker_rootless_env
  fi

  docker="$(command -v docker || true)"
  if [[ -z $docker ]]; then
    for cand in /usr/bin/docker /usr/local/bin/docker; do
      if [[ -x $cand ]]; then
        docker=$cand
        break
      fi
    done
  fi
  if [[ -z $docker ]]; then
    echo "9router: docker is not on PATH" >&2
    exit 1
  fi

  image=${NINEROUTER_IMAGE:-decolua/9router:0.5.69}
  port=${NINEROUTER_PORT:-20128}
  # Published peer is rootlesskit, not loopback. 9Router production local-only
  # routes (tunnel enable) require a loopback TCP hop inside the container.
  app_port=${NINEROUTER_APP_PORT:-$((port + 1))}
  proxy_js=${NINEROUTER_LOOPBACK_PROXY:-}
  if [[ -z $proxy_js ]]; then
    proxy_js="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ninerouter-loopback-proxy.js"
  fi
  if [[ ! -f $proxy_js ]]; then
    echo "9router: loopback proxy missing: $proxy_js" >&2
    exit 1
  fi
  headroom_url=${NINEROUTER_HEADROOM_URL:-http://host.docker.internal:8787}
  # host-gateway is the Docker bridge. In rootless Docker that bridge lives in
  # the rootlesskit netns, so it does not reach host loopback services. Prefer
  # the host default-route IPv4 (override with NINEROUTER_HOST_IP=host-gateway
  # or an explicit address).
  host_ip=${NINEROUTER_HOST_IP-}
  if [[ -z $host_ip ]]; then
    ip_bin=
    for cand in /usr/sbin/ip /sbin/ip /usr/bin/ip; do
      if [[ -x $cand ]]; then
        ip_bin=$cand
        break
      fi
    done
    if [[ -n $ip_bin ]]; then
      host_ip=$(
        { "$ip_bin" -4 route get 1.1.1.1 2>/dev/null || true; } |
          awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}'
      )
    fi
  fi
  if [[ -z $host_ip ]]; then
    host_ip=host-gateway
  fi
  # systemd does not load the devenv .env. home-switch copies INITIAL_PASSWORD
  # to this 0600 file. Also accept the var if the unit already exported it.
  passfile=${NINEROUTER_PASSWORD_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/9router/initial-password}
  if [[ -z ${INITIAL_PASSWORD:-} && -s $passfile ]]; then
    INITIAL_PASSWORD=$(cat "$passfile")
  fi

  # Hash INITIAL_PASSWORD so the tunnel gate sees hasPassword. Do not
  # delete an existing custom hash. Env is still passed for first login.
  if [[ -n ${INITIAL_PASSWORD:-} ]]; then
    nine_router_persist_initial_password "$docker" "$image" "$HOME/.9router" "$INITIAL_PASSWORD" || true
  fi

  # Bind 9Router on loopback inside the container. A TCP proxy on $port
  # forwards the published mapping so dashboardGuard sees 127.0.0.1.
  extra_e=()
  if [[ -n ${INITIAL_PASSWORD:-} ]]; then
    extra_e+=(-e "INITIAL_PASSWORD=$INITIAL_PASSWORD")
  fi
  run=(
    "$docker" run --rm --name 9router
    -p "127.0.0.1:${port}:${port}"
    --add-host=host.docker.internal:"$host_ip"
    -v "$HOME/.9router:/app/data"
    -v "$proxy_js:/ninerouter-loopback-proxy.js:ro"
    -e DATA_DIR=/app/data
    -e HOSTNAME=127.0.0.1
    -e PORT="$app_port"
    -e NINEROUTER_PUBLISH_PORT="$port"
    -e HEADROOM_URL="$headroom_url"
    "${extra_e[@]}"
    "$image"
    /bin/sh -c "node /ninerouter-loopback-proxy.js & exec node custom-server.js"
  )
  if [[ ${NINEROUTER_DRY_RUN:-} == 1 ]]; then
    printf '%s\n' "${run[@]}"
    return 0
  fi
  exec "${run[@]}"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  nine_router_start
fi
