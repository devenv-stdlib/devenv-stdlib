#!/usr/bin/env bash
# Load SecretSpec secrets into the current shell. Provider-agnostic
# (dotenv, keyring, env, …). Sourced by home-switch; sourced by tests.
# shellcheck disable=SC1090

home_load_secrets() {
  local root=${1:-${DEVENV_ROOT:-.}}
  local spec

  if command -v secretspec >/dev/null 2>&1 && [ -f "$root/secretspec.toml" ]; then
    if spec=$(cd "$root" && secretspec export --format shell 2>/dev/null); then
      eval "$spec"
      return 0
    fi
  fi

  if [ -f "$root/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$root/.env"
    set +a
  fi
}
