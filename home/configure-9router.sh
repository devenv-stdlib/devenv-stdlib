#!/usr/bin/env bash
# Point 9Router at Headroom, upsert Brave/Firecrawl, mint a devenv gateway key.
# Sourced by tests; executed from home.activation after 9router is up.
# 9Router has no separate "raw terminal regex" setting; RTK's JS filters
# stay on via rtkEnabled. Ponytail is on; Caveman stays off.

nine_router_wait() {
  local base=$1
  local tries=${2:-30}
  local i
  for ((i = 1; i <= tries; i++)); do
    if curl -fsS --max-time 2 "$base/api/settings" >/dev/null 2>&1 \
      || curl -fsS --max-time 2 "$base/livez" >/dev/null 2>&1 \
      || curl -fsS --max-time 2 "$base/" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

nine_router_password() {
  if [[ -n ${INITIAL_PASSWORD:-} ]]; then
    printf '%s' "$INITIAL_PASSWORD"
    return 0
  fi
  local passfile=${NINEROUTER_PASSWORD_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/9router/initial-password}
  if [[ -s $passfile ]]; then
    cat "$passfile"
    return 0
  fi
  return 1
}

# Login; write a cookie jar. 9Router sets auth_token.
nine_router_login() {
  local base=$1
  local cookie=$2
  local password=$3
  local body
  body=$(jq -n --arg password "$password" '{password: $password}') || return 1
  curl -fsS --max-time 5 -c "$cookie" -b "$cookie" -X POST "$base/api/auth/login" \
    -H 'Content-Type: application/json' \
    -d "$body" >/dev/null
}

nine_router_post_settings() {
  local base=$1
  local cookie=$2
  local headroom_url=$3
  local json
  json=$(
    jq -n '{
      rtkEnabled: true,
      headroomEnabled: false,
      cavemanEnabled: false,
      ponytailEnabled: true,
      ponytailLevel: "full"
    }'
  ) || return 1
  local curl_auth=()
  if [[ -n $cookie && -s $cookie ]]; then
    curl_auth=(-c "$cookie" -b "$cookie")
  fi
  curl -fsS --max-time 5 "${curl_auth[@]}" -X PATCH "$base/api/settings" \
    -H 'Content-Type: application/json' \
    -d "$json" >/dev/null
}

# Upsert a managed apikey connection named "devenv".
nine_router_upsert_apikey() {
  local base=$1
  local cookie=$2
  local provider=$3
  local name=$4
  local api_key=$5
  local list id body
  local curl_auth=(-c "$cookie" -b "$cookie")

  [[ -n $api_key ]] || return 0

  list=$(curl -fsS --max-time 5 "${curl_auth[@]}" "$base/api/providers") || return 1
  id=$(
    jq -r --arg p "$provider" --arg n "$name" '
      [.connections[]? | select(.provider == $p and .name == $n) | .id] | .[0] // empty
    ' <<<"$list"
  )

  if [[ -n $id ]]; then
    body=$(jq -n --arg apiKey "$api_key" --arg name "$name" '{
      apiKey: $apiKey, name: $name, isActive: true
    }') || return 1
    curl -fsS --max-time 5 "${curl_auth[@]}" -X PUT "$base/api/providers/$id" \
      -H 'Content-Type: application/json' \
      -d "$body" >/dev/null
    return
  fi

  body=$(
    jq -n --arg provider "$provider" --arg apiKey "$api_key" --arg name "$name" '{
      provider: $provider, apiKey: $apiKey, name: $name, authType: "apikey"
    }'
  ) || return 1
  curl -fsS --max-time 5 "${curl_auth[@]}" -X POST "$base/api/providers" \
    -H 'Content-Type: application/json' \
    -d "$body" >/dev/null
}

# Create a gateway key named devenv once. Cursor cannot read this from
# settings.json; paste it under Models → Override OpenAI Base URL.
nine_router_ensure_gateway_key() {
  local base=$1
  local cookie=$2
  local dest=${NINEROUTER_CURSOR_KEY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/9router/cursor-api-key}
  local hint=${NINEROUTER_CURSOR_HINT_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/9router/cursor-openai.hint}
  local curl_auth=(-c "$cookie" -b "$cookie")
  local list exists body key

  mkdir -p "$(dirname "$dest")"
  printf '%s\n' \
    "Cursor Settings → Models → Advanced (API Keys)" \
    "  Override OpenAI Base URL: http://127.0.0.1:20128/v1" \
    "  OpenAI API Key: contents of $dest" \
    "Then pick a 9Router model or combo (not Auto / Cursor Grok)." \
    "Built-in Cursor models skip 9Router, so Headroom cannot compact them." \
    "If that file is missing, copy a key from Dashboard → Keys (plaintext is shown only at create time)." \
    >"$hint"

  list=$(curl -fsS --max-time 5 "${curl_auth[@]}" "$base/api/keys") || return 1
  exists=$(jq -r '[.keys[]? | select(.name == "devenv")] | length' <<<"$list")
  if [[ $exists != 0 ]]; then
    return 0
  fi
  if [[ -s $dest ]]; then
    return 0
  fi
  body=$(jq -n '{name: "devenv"}') || return 1
  key=$(
    curl -fsS --max-time 5 "${curl_auth[@]}" -X POST "$base/api/keys" \
      -H 'Content-Type: application/json' \
      -d "$body" | jq -r '.key // empty'
  ) || return 1
  [[ -n $key ]] || return 1
  umask 077
  printf '%s' "$key" >"$dest"
  chmod 600 "$dest"
}

configure_9router() {
  local base=${1:-http://127.0.0.1:20128}
  local headroom_url=${2:-http://host.docker.internal:8787}
  local cookie password

  nine_router_wait "$base" || return 1

  cookie=$(mktemp)
  password=$(nine_router_password || true)
  if [[ -n $password ]]; then
    nine_router_login "$base" "$cookie" "$password" || {
      rm -f "$cookie"
      return 1
    }
  fi

  nine_router_post_settings "$base" "$cookie" "$headroom_url" || {
    rm -f "$cookie"
    return 1
  }

  if [[ -s $cookie ]]; then
    nine_router_upsert_apikey "$base" "$cookie" brave-search devenv "${BRAVE_API_KEY:-}" || {
      rm -f "$cookie"
      return 1
    }
    nine_router_upsert_apikey "$base" "$cookie" firecrawl devenv "${FIRECRAWL_API_KEY:-}" || {
      rm -f "$cookie"
      return 1
    }
    nine_router_ensure_gateway_key "$base" "$cookie" || {
      rm -f "$cookie"
      return 1
    }
  fi
  rm -f "$cookie"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  set -euo pipefail
  configure_9router "$@"
fi
