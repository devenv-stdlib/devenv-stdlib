#!/usr/bin/env bash
# Build act CLI / docker env fragments so nested mise can call api.github.com.
# Sourced by test-devenv and tests/act-token.bats.
#
# Name-only `act --env GITHUB_TOKEN` / docker `--env GITHUB_TOKEN` is not enough:
# act may inject an empty/dummy secret (401 Bad credentials for mise), and mise
# also honors MISE_GITHUB_TOKEN / GH_TOKEN. Always pass explicit values via
# `-s` (act secret) and `--env KEY=value`.

act_github_token_prepare() {
  # shellcheck disable=SC2034 # set for callers (test-devenv) after source
  ACT_GITHUB_TOKEN_OPTS=
  # shellcheck disable=SC2034
  ACT_GITHUB_TOKEN_ARGS=()
  local token=${GITHUB_TOKEN:-${GH_TOKEN:-${MISE_GITHUB_TOKEN:-}}}
  if [[ -z $token ]]; then
    return 0
  fi
  # shellcheck disable=SC2034
  ACT_GITHUB_TOKEN_OPTS="--env GITHUB_TOKEN=${token} --env MISE_GITHUB_TOKEN=${token} --env GH_TOKEN=${token}"
  # shellcheck disable=SC2034
  ACT_GITHUB_TOKEN_ARGS=(
    -s "GITHUB_TOKEN=${token}"
    --env "GITHUB_TOKEN=${token}"
    --env "MISE_GITHUB_TOKEN=${token}"
    --env "GH_TOKEN=${token}"
  )
}
