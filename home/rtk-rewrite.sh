#!/usr/bin/env bash
# shellcheck disable=SC2016
# Cursor preToolUse hook: rewrite Shell commands through rtk.
# RTK and JQ are absolute (GNOME Cursor often has a thin PATH).
# Sourced by tests when RTK/JQ are set; exec'd from the Home Manager wrapper.
# Do not run `rtk init` — it can install the buggy native `rtk hook cursor` path.
#
# Cursor ignores hook permission:allow for Shell auto-run; terminalAllowlist must
# match the first token of updated_input.command. Activation installs a stable
# $HOME/.cursor/bin/rtk and lists that path (plus bare "rtk") in permissions.json.
# Always emit permission allow + absolute $RTK for rewritten or wrapped commands.
# rtk rewrite exit 0 or 3 = apply rewrite (0.48+ often uses 3); 1 = no filter;
# 2 = deny. Unfiltered commands become `$RTK run -c …` (raw via RTK).

emit_allow() {
  "$JQ" -n --arg cmd "$1" '{
    "continue": true,
    "permission": "allow",
    "updated_input": { "command": $cmd }
  }'
}

# Prefer absolute $RTK so thin Agent PATH and allowlist stay aligned.
abs_rtk_cmd() {
  local cmd=$1
  case $cmd in
  rtk)
    printf '%s\n' "$RTK"
    ;;
  rtk\ *)
    printf '%s %s\n' "$RTK" "${cmd#rtk }"
    ;;
  *)
    printf '%s\n' "$cmd"
    ;;
  esac
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
    emit_allow "$(abs_rtk_cmd "$REWRITTEN")"
    exit 0
  fi
  # Already an RTK command (or no-op rewrite): force absolute + allow.
  emit_allow "$(abs_rtk_cmd "$CMD")"
  exit 0
fi

# No specialized filter (or empty rewrite): keep the allowlist green via rtk run.
case $CMD in
rtk | rtk\ *)
  emit_allow "$(abs_rtk_cmd "$CMD")"
  exit 0
  ;;
esac

# Also rewrite absolute stable-bin prefixes to keep first token stable.
case $CMD in
"$RTK" | "$RTK"\ *)
  emit_allow "$CMD"
  exit 0
  ;;
esac

WRAPPED=$("$JQ" -nr --arg rtk "$RTK" --arg cmd "$CMD" '"\($rtk) run -c " + ($cmd | @sh)')
emit_allow "$WRAPPED"
