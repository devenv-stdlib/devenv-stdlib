#!/usr/bin/env bats
# Unit tests for modules/test/act-github-env.sh (nested act → mise GitHub auth).

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # shellcheck disable=SC1091
  source "$REPO_DIR/modules/test/act-github-env.sh"
  unset GITHUB_TOKEN GH_TOKEN MISE_GITHUB_TOKEN
  ACT_GITHUB_TOKEN_OPTS=
  ACT_GITHUB_TOKEN_ARGS=()
}

@test "act_github_token_prepare is a no-op without tokens" {
  act_github_token_prepare
  [ -z "$ACT_GITHUB_TOKEN_OPTS" ]
  [ "${#ACT_GITHUB_TOKEN_ARGS[@]}" -eq 0 ]
}

@test "act_github_token_prepare emits explicit values and -s from GITHUB_TOKEN" {
  GITHUB_TOKEN=ghs_testvalue act_github_token_prepare
  [[ "$ACT_GITHUB_TOKEN_OPTS" == *"--env GITHUB_TOKEN=ghs_testvalue"* ]]
  [[ "$ACT_GITHUB_TOKEN_OPTS" == *"--env MISE_GITHUB_TOKEN=ghs_testvalue"* ]]
  [[ "$ACT_GITHUB_TOKEN_OPTS" == *"--env GH_TOKEN=ghs_testvalue"* ]]
  # Each flag/value is its own argv word when expanding ACT_GITHUB_TOKEN_ARGS.
  [ "${#ACT_GITHUB_TOKEN_ARGS[@]}" -eq 8 ]
  [ "${ACT_GITHUB_TOKEN_ARGS[0]}" = "-s" ]
  [ "${ACT_GITHUB_TOKEN_ARGS[1]}" = "GITHUB_TOKEN=ghs_testvalue" ]
  [ "${ACT_GITHUB_TOKEN_ARGS[2]}" = "--env" ]
  [ "${ACT_GITHUB_TOKEN_ARGS[3]}" = "GITHUB_TOKEN=ghs_testvalue" ]
  [ "${ACT_GITHUB_TOKEN_ARGS[4]}" = "--env" ]
  [ "${ACT_GITHUB_TOKEN_ARGS[5]}" = "MISE_GITHUB_TOKEN=ghs_testvalue" ]
  [ "${ACT_GITHUB_TOKEN_ARGS[6]}" = "--env" ]
  [ "${ACT_GITHUB_TOKEN_ARGS[7]}" = "GH_TOKEN=ghs_testvalue" ]
}

@test "act_github_token_prepare falls back to GH_TOKEN then MISE_GITHUB_TOKEN" {
  GH_TOKEN=gh_fallback act_github_token_prepare
  [[ "$ACT_GITHUB_TOKEN_OPTS" == *"--env GITHUB_TOKEN=gh_fallback"* ]]

  unset GH_TOKEN
  ACT_GITHUB_TOKEN_OPTS=
  ACT_GITHUB_TOKEN_ARGS=()
  MISE_GITHUB_TOKEN=mise_fallback act_github_token_prepare
  [[ "$ACT_GITHUB_TOKEN_OPTS" == *"--env GITHUB_TOKEN=mise_fallback"* ]]
}
