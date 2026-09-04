#!/usr/bin/env bash
# Apply Warp Quake mode, Wayland, and Starship settings to the current user.
# Sourcing this file defines the helpers without touching the home directory.

set -u

: "${WARP_QUAKE_KEYBINDING:=f12}"
: "${WARP_ENABLE_WAYLAND:=1}"
: "${WARP_CONFIG_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}/warp-terminal}"
: "${WARP_BIN_DIR:=${HOME}/.local/bin}"
: "${WARP_APPLICATIONS_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/applications}"
: "${WARP_BASHRC:=${HOME}/.bashrc}"
: "${WARP_STARSHIP_INIT:=eval \"\$(starship init bash)\"}"

WARP_SETTINGS="${WARP_CONFIG_DIR}/settings.toml"
WARP_LAUNCHER="${WARP_BIN_DIR}/warp-terminal"
WARP_DESKTOP="${WARP_APPLICATIONS_DIR}/dev.warp.Warp.desktop"
GNOME_SHORTCUT_PATH='/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/devenv-warp-quake/'

ok() {
  printf '✓ %s\n' "$*"
}

warn() {
  printf '✗ %s\n' "$*" >&2
}

# Warp uses "ctrl-shift-f12"; GNOME custom shortcuts use "<Ctrl><Shift>F12".
warp_to_gnome_binding() {
  local spec=${1,,} token out=""
  local -a tokens

  [[ -n $spec ]] || return 1
  IFS='-' read -r -a tokens <<<"$spec"
  ((${#tokens[@]} > 0)) || return 1

  for token in "${tokens[@]}"; do
    case $token in
      ctrl | control) out+='<Ctrl>' ;;
      alt | opt | option) out+='<Alt>' ;;
      shift) out+='<Shift>' ;;
      super | cmd | win | meta) out+='<Super>' ;;
      enter | return) out+='Return' ;;
      space) out+='space' ;;
      tab) out+='Tab' ;;
      grave | '`' | backquote) out+='grave' ;;
      esc | escape) out+='Escape' ;;
      f[0-9] | f1[0-9] | f2[0-4]) out+="${token^^}" ;;
      [a-z0-9]) out+="$token" ;;
      *) out+="$token" ;;
    esac
  done

  printf '%s\n' "$out"
}

write_warp_settings() {
  local keybinding=$1
  cat <<EOF
# Managed by devenv scripts/apply-warp.sh. Unmanaged tables are kept.

[system]
force_x11 = false

[terminal.input]
honor_ps1 = true

[global_hotkey.dedicated_window]
enabled = true

[global_hotkey.dedicated_window.settings]
active_pin_position = "top"
hide_window_when_unfocused = true
keybinding = "${keybinding}"

[global_hotkey.dedicated_window.settings.pin_position_to_size_percentages.top]
width = 100
height = 30
EOF
}

# Keep keys we do not manage. Recreate the managed tables from scratch so a
# previous keybinding or honor_ps1 = false cannot linger.
merge_warp_settings() {
  local dest=$1 keybinding=$2 tmp
  tmp=$(mktemp)
  if [[ -f $dest ]] && command -v python3 >/dev/null 2>&1; then
    if ! python3 - "$dest" "$tmp" <<'PY'; then
import pathlib
import re
import sys

src, dest = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
text = src.read_text()
# Drop every managed table, including ones the user may have edited by hand.
for header in (
    "system",
    "terminal.input",
    "global_hotkey.dedicated_window",
    "global_hotkey.dedicated_window.settings",
    "global_hotkey.dedicated_window.settings.pin_position_to_size_percentages.top",
):
    text = re.sub(rf"(?ms)^\[{re.escape(header)}\][^\[]*", "", text)
text = re.sub(r"(?m)^# Managed by devenv.*\n(?:# .*\n)*", "", text)
text = re.sub(r"(?m)^# subsequent runs; only the tables below are replaced.\n", "", text)
text = re.sub(r"\n{3,}", "\n\n", text).strip()
dest.write_text(text + ("\n\n" if text else ""))
PY
      warn "could not merge $dest; rewriting managed tables only"
      : >"$tmp"
    fi
  else
    : >"$tmp"
  fi

  {
    cat "$tmp"
    write_warp_settings "$keybinding"
  } >"${dest}.tmp"
  mv "${dest}.tmp" "$dest"
  rm -f "$tmp"
}

# Split out from install_launcher so tests can stub the lookup instead of
# depending on whether warp-terminal happens to be on PATH.
warp_terminal_path() {
  command -v warp-terminal 2>/dev/null
}

install_launcher() {
  local src
  src=$(warp_terminal_path) || return 1
  [[ -n $src ]] || return 1
  mkdir -p "$WARP_BIN_DIR"
  cat >"$WARP_LAUNCHER" <<EOF
#!/usr/bin/env bash
export WARP_ENABLE_WAYLAND=${WARP_ENABLE_WAYLAND}
exec $(printf '%q' "$src") "\$@"
EOF
  chmod +x "$WARP_LAUNCHER"
}

install_desktop_entry() {
  local exec_path=${1:-$WARP_LAUNCHER}
  mkdir -p "$WARP_APPLICATIONS_DIR"
  cat >"$WARP_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Warp
GenericName=Terminal Emulator
Comment=Warp terminal with Wayland and Quake mode
Exec=env WARP_ENABLE_WAYLAND=${WARP_ENABLE_WAYLAND} ${exec_path} %U
Icon=warp-terminal
Terminal=false
Categories=System;TerminalEmulator;
StartupWMClass=dev.warp.Warp
Keywords=shell;prompt;command;commandline;cmd;
EOF
}

# Warp cannot register its own global hotkey on Wayland, so F12 (or whatever
# warp.quakeKeybinding is) is also bound as a GNOME custom shortcut that
# launches the same wrapper. A second launch focuses the existing Warp window.
install_gnome_shortcut() {
  local binding command_path schema list entry
  command -v gsettings >/dev/null 2>&1 || return 1
  gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.settings-daemon.plugins.media-keys' || return 1

  binding=$(warp_to_gnome_binding "$WARP_QUAKE_KEYBINDING") || return 1
  command_path=${1:-$WARP_LAUNCHER}
  schema='org.gnome.settings-daemon.plugins.media-keys'
  entry="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${GNOME_SHORTCUT_PATH}"

  list=$(gsettings get "$schema" custom-keybindings)
  if [[ $list != *"$GNOME_SHORTCUT_PATH"* ]]; then
    if [[ $list == '@as []' || $list == '[]' ]]; then
      gsettings set "$schema" custom-keybindings "['${GNOME_SHORTCUT_PATH}']"
    else
      gsettings set "$schema" custom-keybindings "${list%]*}, '${GNOME_SHORTCUT_PATH}']"
    fi
  fi

  gsettings set "$entry" name 'Warp Quake'
  gsettings set "$entry" command "$command_path"
  gsettings set "$entry" binding "$binding"
}

ensure_starship_bashrc() {
  local rc=$1
  [[ -f $rc ]] || return 1
  if grep -Fq 'starship init bash' "$rc"; then
    return 0
  fi
  printf '\n# Starship prompt (added by devenv scripts/apply-warp.sh)\n%s\n' \
    "$WARP_STARSHIP_INIT" >>"$rc"
}

apply_warp() {
  mkdir -p "$WARP_CONFIG_DIR"

  merge_warp_settings "$WARP_SETTINGS" "$WARP_QUAKE_KEYBINDING"
  ok "wrote Warp settings (Quake ${WARP_QUAKE_KEYBINDING}, honor_ps1, Wayland)"

  if install_launcher; then
    ok "installed ${WARP_LAUNCHER}"
    install_desktop_entry "$WARP_LAUNCHER"
    ok "installed ${WARP_DESKTOP}"
    if install_gnome_shortcut "$WARP_LAUNCHER"; then
      ok "bound GNOME shortcut $(warp_to_gnome_binding "$WARP_QUAKE_KEYBINDING") to Warp Quake"
    else
      printf 'warp: GNOME shortcut not installed (gsettings unavailable or not GNOME)\n'
    fi
  else
    warn "warp-terminal is not on PATH; skip launcher and desktop entry"
  fi

  if [[ -f $WARP_BASHRC ]]; then
    if ensure_starship_bashrc "$WARP_BASHRC"; then
      ok "Starship init present in ${WARP_BASHRC}"
    else
      warn "could not update ${WARP_BASHRC}"
    fi
  fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  apply_warp "$@"
fi
