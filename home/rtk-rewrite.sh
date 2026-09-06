#!/usr/bin/env bash
# shellcheck disable=SC2016
# Cursor preToolUse hook: rewrite Shell commands through rtk.
# RTK and JQ are absolute (GNOME Cursor often has a thin PATH).
# Sourced by tests when RTK/JQ are set; exec'd from the Home Manager wrapper.
# Do not run `rtk init` — it can install the buggy native `rtk hook cursor` path.

if [[ -z ${RTK:-} || ! -x ${RTK} ]]; then
  echo "[rtk] WARNING: RTK binary is missing. Hook cannot rewrite commands." >&2
  echo '{}'
  exit 0
fi

if [[ -z ${JQ:-} || ! -x ${JQ} ]]; then
  echo "[rtk] WARNING: jq is missing. Hook cannot rewrite commands." >&2
  echo '{}'
  exit 0
fi

INPUT=$(cat)
CMD=$("$JQ" -r '.tool_input.command // empty' <<<"$INPUT")

if [[ -z ${CMD} ]]; then
  echo '{}'
  exit 0
fi

# Exit codes: 0 = allow rewrite, 1 = no rewrite, 2 = deny, 3 = ask/default
# (success with output). 0 and 3 both apply the rewrite.
REWRITTEN=$("$RTK" rewrite "$CMD" 2>/dev/null)
RC=$?
if [[ $RC -ne 0 && $RC -ne 3 ]]; then
  echo '{}'
  exit 0
fi

if [[ -z ${REWRITTEN} || ${CMD} == "${REWRITTEN}" ]]; then
  echo '{}'
  exit 0
fi

PERMISSION=allow
if [[ $RC -eq 3 ]]; then
  PERMISSION=ask
fi

"$JQ" -n --arg cmd "$REWRITTEN" --arg perm "$PERMISSION" '{
  "continue": true,
  "permission": $perm,
  "updated_input": { "command": $cmd }
}'
