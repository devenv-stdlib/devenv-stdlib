#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# ^ SC2030/SC2031: each @test looks like a subshell, so secret exports are
# reported as leaking or getting lost; they are deliberately per-test.
# Exercises home/configure-9router.sh against a fake curl. No live 9Router.

bats_require_minimum_version 1.5.0

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$REPO_DIR/home/configure-9router.sh"
  command -v jq >/dev/null || skip "jq not installed"
  TMP=$(mktemp -d)
  export PATH="$TMP/bin:$PATH"
  export HOME="$TMP/home"
  # devenv/CI export XDG_CONFIG_HOME; pin it under the fake HOME so scripts
  # and assertions agree on ~/.config/9router paths.
  export XDG_CONFIG_HOME="$HOME/.config"
  mkdir -p "$HOME/.config/9router" "$TMP/bin" "$TMP/http"
  cat >"$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log=${CURL_LOG:-/tmp/curl.log}
method=GET
url=""
data=""
cookie_out=""
args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
  a=${args[$i]}
  case $a in
    -X)
      i=$((i + 1))
      method=${args[$i]}
      ;;
    -d)
      i=$((i + 1))
      data=${args[$i]}
      ;;
    -c)
      i=$((i + 1))
      cookie_out=${args[$i]}
      ;;
    http://* | https://*) url=$a ;;
  esac
  i=$((i + 1))
done
if [[ -n $cookie_out ]]; then
  printf '# Netscape HTTP Cookie File\n127.0.0.1\tFALSE\t/\tFALSE\t0\tauth_token\tfake\n' >"$cookie_out"
fi
# Do not persist login passwords in the fake access log.
if [[ $url == */api/auth/login ]]; then
  printf '%s %s\n' "$method" "$url" >>"$log"
else
  printf '%s %s %s\n' "$method" "$url" "$data" >>"$log"
fi
case $method:$url in
  GET:*/api/providers)
    cat "${FAKE_PROVIDERS:-/dev/null}"
    ;;
  GET:*/api/keys)
    if [[ -n ${FAKE_KEYS:-} && -s $FAKE_KEYS ]]; then
      cat "$FAKE_KEYS"
    else
      echo '{"keys":[]}'
    fi
    ;;
  POST:*/api/keys)
    echo '{"key":"sk-test-devenv","name":"devenv","id":"1"}'
    ;;
  POST:*/api/auth/login | PATCH:*/api/settings | POST:*/api/providers | PUT:*/api/providers/*)
    echo '{"ok":true}'
    ;;
  *)
    echo '{"ok":true}'
    ;;
esac
EOF
  chmod +x "$TMP/bin/curl"
  export CURL_LOG="$TMP/curl.log"
}

teardown() {
  rm -rf "$TMP"
}

@test "nine_router_password reads INITIAL_PASSWORD then the 0600 file" {
  unset INITIAL_PASSWORD
  run nine_router_password
  [ "$status" -ne 0 ]
  printf 'from-file' >"$HOME/.config/9router/initial-password"
  run nine_router_password
  [ "$status" -eq 0 ]
  [ "$output" = "from-file" ]
  INITIAL_PASSWORD=from-env
  run nine_router_password
  [ "$output" = "from-env" ]
}

@test "configure_9router logs in and upserts Brave and Firecrawl" {
  export INITIAL_PASSWORD=test-9r
  export BRAVE_API_KEY=test-brave
  export FIRECRAWL_API_KEY=test-fire
  printf '%s\n' '{"connections":[]}' >"$TMP/http/providers.json"
  export FAKE_PROVIDERS="$TMP/http/providers.json"

  run configure_9router http://127.0.0.1:20128 http://host.docker.internal:8787
  [ "$status" -eq 0 ]
  grep -q 'POST http://127.0.0.1:20128/api/auth/login' "$CURL_LOG"
  grep -q 'PATCH http://127.0.0.1:20128/api/settings' "$CURL_LOG"
  grep -qE '"headroomEnabled":[[:space:]]*false' "$CURL_LOG"
  run ! grep -q 'headroomUrl' "$CURL_LOG"
  grep -q 'ponytailEnabled' "$CURL_LOG"
  grep -q 'brave-search' "$CURL_LOG"
  grep -q 'firecrawl' "$CURL_LOG"
  grep -q 'test-brave' "$CURL_LOG"
  grep -q 'test-fire' "$CURL_LOG"
  grep -q 'POST http://127.0.0.1:20128/api/keys' "$CURL_LOG"
  [ "$(cat "$HOME/.config/9router/cursor-api-key")" = "sk-test-devenv" ]
  grep -q 'Override OpenAI Base URL' "$HOME/.config/9router/cursor-openai.hint"
  run ! grep -q 'test-9r' "$CURL_LOG"
}

@test "configure_9router skips creating a gateway key when devenv exists" {
  export INITIAL_PASSWORD=test-9r
  unset BRAVE_API_KEY FIRECRAWL_API_KEY
  printf '%s\n' '{"keys":[{"name":"devenv","id":"1"}]}' >"$TMP/http/keys.json"
  export FAKE_KEYS="$TMP/http/keys.json"
  run configure_9router http://127.0.0.1:20128
  [ "$status" -eq 0 ]
  run ! grep -q 'POST http://127.0.0.1:20128/api/keys' "$CURL_LOG"
  [ ! -f "$HOME/.config/9router/cursor-api-key" ]
  grep -q 'Override OpenAI Base URL' "$HOME/.config/9router/cursor-openai.hint"
}

@test "configure_9router skips creating a gateway key when the local file exists" {
  export INITIAL_PASSWORD=test-9r
  unset BRAVE_API_KEY FIRECRAWL_API_KEY
  printf '%s' 'sk-already' >"$HOME/.config/9router/cursor-api-key"
  run configure_9router http://127.0.0.1:20128
  [ "$status" -eq 0 ]
  run ! grep -q 'POST http://127.0.0.1:20128/api/keys' "$CURL_LOG"
  [ "$(cat "$HOME/.config/9router/cursor-api-key")" = "sk-already" ]
}

@test "configure_9router PUTs when a devenv connection already exists" {
  export INITIAL_PASSWORD=test-9r
  export BRAVE_API_KEY=test-brave
  unset FIRECRAWL_API_KEY
  printf '%s\n' '{"connections":[{"id":"conn-1","provider":"brave-search","name":"devenv"}]}' \
    >"$TMP/http/providers.json"
  export FAKE_PROVIDERS="$TMP/http/providers.json"

  run configure_9router http://127.0.0.1:20128
  [ "$status" -eq 0 ]
  grep -q 'PUT http://127.0.0.1:20128/api/providers/conn-1' "$CURL_LOG"
  run ! grep -q 'firecrawl' "$CURL_LOG"
}
