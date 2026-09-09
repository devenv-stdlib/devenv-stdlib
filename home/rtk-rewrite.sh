#!/usr/bin/env bash
# shellcheck disable=SC2016
# Cursor preToolUse hook: rewrite Shell commands through rtk.
# RTK and JQ are absolute (GNOME Cursor often has a thin PATH).
# Sourced by tests when RTK/JQ are set; exec'd from the Home Manager wrapper.
# Do not run `rtk init` — it can install the buggy native `rtk hook cursor` path.
#
# terminalAllowlist is ["rtk"] only. Always emit permission allow for rewritten
# or rtk-wrapped commands so Cursor does not prompt on mundane Shell use.
# rtk rewrite exit 0 or 3 = apply rewrite (0.48+ often uses 3); 1 = no filter;
# 2 = deny. Unfiltered commands become `rtk run -c …` (raw via RTK).

emit_allow() {
  "$JQ" -n --arg cmd "$1" '{
    "continue": true,
    "permission": "allow",
    "updated_input": { "command": $cmd }
  }'
}

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

REWRITTEN=$("$RTK" rewrite "$CMD" 2>/dev/null)
RC=$?

if [[ ($RC -eq 0 || $RC -eq 3) && -n ${REWRITTEN} ]]; then
  if [[ ${CMD} != "${REWRITTEN}" ]]; then
    emit_allow "$REWRITTEN"
    exit 0
  fi
  # Already an RTK command (or no-op rewrite): leave input; allowlist matches.
  echo '{}'
  exit 0
fi

# No specialized filter (or empty rewrite): keep the allowlist green via rtk run.
case $CMD in
rtk | rtk\ *)
  echo '{}'
  exit 0
  ;;
esac

WRAPPED=$("$JQ" -nr --arg cmd "$CMD" '"rtk run -c " + ($cmd | @sh)')
emit_allow "$WRAPPED"
