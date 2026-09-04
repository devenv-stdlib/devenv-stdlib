#!/usr/bin/env bats
# shellcheck disable=SC2016
# ^ The in_apply snippets are single-quoted on purpose: they are evaluated in a
# subshell that sources apply-warp.sh, where the WARP_* variables are exported.
#
# Unit tests for scripts/apply-warp.sh. Paths are redirected so nothing here
# writes into the real ~/.config or GNOME settings.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  APPLY="$REPO_DIR/scripts/apply-warp.sh"
  HOME="$BATS_TEST_TMPDIR/home"
  export HOME
  export WARP_CONFIG_DIR="$HOME/.config/warp-terminal"
  export WARP_BIN_DIR="$HOME/.local/bin"
  export WARP_APPLICATIONS_DIR="$HOME/.local/share/applications"
  export WARP_BASHRC="$HOME/.bashrc"
  export WARP_QUAKE_KEYBINDING="f12"
  export WARP_SETTINGS="$WARP_CONFIG_DIR/settings.toml"
  export WARP_LAUNCHER="$WARP_BIN_DIR/warp-terminal"
  export WARP_DESKTOP="$WARP_APPLICATIONS_DIR/dev.warp.Warp.desktop"
  mkdir -p "$HOME" "$WARP_CONFIG_DIR" "$WARP_BIN_DIR" "$WARP_APPLICATIONS_DIR"
  printf 'existing bashrc\n' >"$WARP_BASHRC"

  # gsettings talks to the live GNOME session; keep tests off the host. Tests
  # that exercise the shortcut replace this with stub_gsettings.
  STUB_DIR="$BATS_TEST_TMPDIR/stub-bin"
  mkdir -p "$STUB_DIR"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$STUB_DIR/gsettings"
  chmod +x "$STUB_DIR/gsettings"
  export PATH="$STUB_DIR:$PATH"
}

in_apply() {
  run bash -c "source '$APPLY'; $1"
}

# A gsettings that records every call and keeps the custom-keybindings list in
# a file, so the append logic can be asserted without a GNOME session.
# Usage: stub_gsettings [initial_list] [schemas]
stub_gsettings() {
  GS_LOG="$BATS_TEST_TMPDIR/gsettings.log"
  GS_STATE="$BATS_TEST_TMPDIR/gsettings.state"
  : >"$GS_LOG"
  printf '%s\n' "${1-@as []}" >"$GS_STATE"
  GS_SCHEMAS="${2-org.gnome.settings-daemon.plugins.media-keys}"
  export GS_LOG GS_STATE GS_SCHEMAS
  cat >"$STUB_DIR/gsettings" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GS_LOG"
case $1 in
  list-schemas)
    [[ -n ${GS_SCHEMAS:-} ]] && printf '%s\n' "$GS_SCHEMAS"
    ;;
  get)
    cat "$GS_STATE"
    ;;
  set)
    if [[ $3 == custom-keybindings ]]; then
      printf '%s\n' "$4" >"$GS_STATE"
    fi
    ;;
esac
exit 0
STUB
  chmod +x "$STUB_DIR/gsettings"
}

# Put a fake warp-terminal on PATH so install_launcher has something to wrap.
stub_warp_bin() {
  printf '#!/usr/bin/env bash\nexit 0\n' >"$STUB_DIR/warp-terminal"
  chmod +x "$STUB_DIR/warp-terminal"
}

@test "apply-warp.sh passes shellcheck" {
  command -v shellcheck >/dev/null || skip "shellcheck not installed"
  run shellcheck "$APPLY"
  [ "$status" -eq 0 ]
}

@test "warp_to_gnome_binding maps f12 to F12" {
  in_apply 'warp_to_gnome_binding f12'
  [ "$status" -eq 0 ]
  [ "$output" = "F12" ]
}

@test "warp_to_gnome_binding maps ctrl-shift-f12" {
  in_apply 'warp_to_gnome_binding ctrl-shift-f12'
  [ "$status" -eq 0 ]
  [ "$output" = "<Ctrl><Shift>F12" ]
}

@test "warp_to_gnome_binding maps ctrl-\` to grave" {
  in_apply 'warp_to_gnome_binding "ctrl-\`"'
  [ "$status" -eq 0 ]
  [ "$output" = "<Ctrl>grave" ]
}

@test "warp_to_gnome_binding maps alt-enter" {
  in_apply 'warp_to_gnome_binding alt-enter'
  [ "$status" -eq 0 ]
  [ "$output" = "<Alt>Return" ]
}

@test "warp_to_gnome_binding maps super and cmd to <Super>" {
  in_apply 'warp_to_gnome_binding super-space'
  [ "$output" = "<Super>space" ]
  in_apply 'warp_to_gnome_binding cmd-t'
  [ "$output" = "<Super>t" ]
}

@test "warp_to_gnome_binding accepts uppercase input" {
  in_apply 'warp_to_gnome_binding CTRL-SHIFT-F5'
  [ "$status" -eq 0 ]
  [ "$output" = "<Ctrl><Shift>F5" ]
}

@test "warp_to_gnome_binding rejects an empty keybinding" {
  in_apply 'warp_to_gnome_binding ""'
  [ "$status" -ne 0 ]
}

@test "merge_warp_settings writes Quake, honor_ps1, and Wayland keys" {
  in_apply 'merge_warp_settings "$WARP_SETTINGS" f12'
  [ "$status" -eq 0 ]
  run cat "$WARP_SETTINGS"
  [[ $output == *'honor_ps1 = true'* ]]
  [[ $output == *'force_x11 = false'* ]]
  [[ $output == *'enabled = true'* ]]
  [[ $output == *'keybinding = "f12"'* ]]
}

@test "merge_warp_settings keeps unrelated user tables" {
  cat >"$WARP_SETTINGS" <<'EOF'
[appearance.text]
font_size = 15.0

[system]
force_x11 = true
EOF
  in_apply 'merge_warp_settings "$WARP_SETTINGS" f12'
  [ "$status" -eq 0 ]
  run cat "$WARP_SETTINGS"
  [[ $output == *'font_size = 15.0'* ]]
  [[ $output == *'force_x11 = false'* ]]
  [[ $output != *'force_x11 = true'* ]]
}

@test "merge_warp_settings replaces a previous keybinding" {
  in_apply 'merge_warp_settings "$WARP_SETTINGS" ctrl-\`'
  in_apply 'merge_warp_settings "$WARP_SETTINGS" f12'
  run cat "$WARP_SETTINGS"
  [[ $output == *'keybinding = "f12"'* ]]
  [[ $output != *'ctrl-'* ]]
}

@test "merge_warp_settings pins the Quake window to the top edge" {
  in_apply 'merge_warp_settings "$WARP_SETTINGS" f12'
  run cat "$WARP_SETTINGS"
  [[ $output == *'active_pin_position = "top"'* ]]
  [[ $output == *'hide_window_when_unfocused = true'* ]]
  [[ $output == *'pin_position_to_size_percentages.top'* ]]
}

@test "merge_warp_settings does not duplicate its managed header" {
  in_apply 'merge_warp_settings "$WARP_SETTINGS" f12'
  in_apply 'merge_warp_settings "$WARP_SETTINGS" f12'
  in_apply 'merge_warp_settings "$WARP_SETTINGS" f12'
  run grep -c '^# Managed by devenv' "$WARP_SETTINGS"
  [ "$output" = "1" ]
}

@test "merge_warp_settings does not duplicate managed tables" {
  in_apply 'merge_warp_settings "$WARP_SETTINGS" f12'
  in_apply 'merge_warp_settings "$WARP_SETTINGS" f12'
  run grep -c '^\[terminal.input\]' "$WARP_SETTINGS"
  [ "$output" = "1" ]
  run grep -c '^\[global_hotkey.dedicated_window\]' "$WARP_SETTINGS"
  [ "$output" = "1" ]
}

@test "merge_warp_settings still writes managed keys without python3" {
  printf '#!/usr/bin/env bash\nexit 127\n' >"$STUB_DIR/python3"
  chmod +x "$STUB_DIR/python3"
  cat >"$WARP_SETTINGS" <<'EOF'
[appearance.text]
font_size = 15.0
EOF
  in_apply 'merge_warp_settings "$WARP_SETTINGS" f12'
  [ "$status" -eq 0 ]
  run cat "$WARP_SETTINGS"
  [[ $output == *'keybinding = "f12"'* ]]
  [[ $output == *'honor_ps1 = true'* ]]
}

@test "merge_warp_settings creates the file when absent" {
  rm -f "$WARP_SETTINGS"
  in_apply 'merge_warp_settings "$WARP_SETTINGS" f12'
  [ "$status" -eq 0 ]
  [ -f "$WARP_SETTINGS" ]
  run cat "$WARP_SETTINGS"
  [[ $output == *'keybinding = "f12"'* ]]
}

@test "install_gnome_shortcut registers name, command, and binding" {
  stub_gsettings
  in_apply 'install_gnome_shortcut /usr/local/bin/warp-terminal'
  [ "$status" -eq 0 ]
  run cat "$GS_LOG"
  [[ $output == *'name Warp Quake'* ]]
  [[ $output == *'command /usr/local/bin/warp-terminal'* ]]
  [[ $output == *'binding F12'* ]]
}

@test "install_gnome_shortcut adds the path to an empty keybinding list" {
  stub_gsettings '@as []'
  in_apply 'install_gnome_shortcut /usr/local/bin/warp-terminal'
  [ "$status" -eq 0 ]
  run cat "$GS_STATE"
  [ "$output" = "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/devenv-warp-quake/']" ]
}

@test "install_gnome_shortcut appends without dropping existing shortcuts" {
  stub_gsettings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
  in_apply 'install_gnome_shortcut /usr/local/bin/warp-terminal'
  [ "$status" -eq 0 ]
  run cat "$GS_STATE"
  [[ $output == *'custom0/'* ]]
  [[ $output == *'devenv-warp-quake/'* ]]
}

@test "install_gnome_shortcut does not add a duplicate entry on re-run" {
  stub_gsettings
  in_apply 'install_gnome_shortcut /usr/local/bin/warp-terminal'
  in_apply 'install_gnome_shortcut /usr/local/bin/warp-terminal'
  [ "$status" -eq 0 ]
  run grep -c 'devenv-warp-quake' "$GS_STATE"
  [ "$output" = "1" ]
}

@test "install_gnome_shortcut uses the configured keybinding" {
  stub_gsettings
  WARP_QUAKE_KEYBINDING='ctrl-shift-f9' in_apply 'install_gnome_shortcut /usr/local/bin/warp-terminal'
  [ "$status" -eq 0 ]
  run cat "$GS_LOG"
  [[ $output == *'binding <Ctrl><Shift>F9'* ]]
}

@test "install_gnome_shortcut bails out when the media-keys schema is absent" {
  stub_gsettings '@as []' ''
  in_apply 'install_gnome_shortcut /usr/local/bin/warp-terminal'
  [ "$status" -ne 0 ]
  run grep -c '^set' "$GS_LOG"
  [ "$output" = "0" ]
}

@test "install_gnome_shortcut bails out when gsettings is missing" {
  rm -f "$STUB_DIR/gsettings"
  ln -sf "$(command -v bash)" "$STUB_DIR/bash"
  run env PATH="$STUB_DIR" bash -c "source '$APPLY'; install_gnome_shortcut /usr/local/bin/warp-terminal"
  [ "$status" -eq 1 ]
}

@test "install_launcher fails when warp-terminal cannot be found" {
  in_apply 'warp_terminal_path() { return 1; }; install_launcher'
  [ "$status" -ne 0 ]
  [ ! -e "$WARP_LAUNCHER" ]
}

@test "warp_terminal_path resolves warp-terminal from PATH" {
  stub_warp_bin
  in_apply 'warp_terminal_path'
  [ "$status" -eq 0 ]
  [ "$output" = "$STUB_DIR/warp-terminal" ]
}

@test "install_launcher wraps the resolved warp-terminal path" {
  stub_warp_bin
  in_apply 'install_launcher'
  [ "$status" -eq 0 ]
  run cat "$WARP_LAUNCHER"
  [[ $output == *'export WARP_ENABLE_WAYLAND=1'* ]]
  [[ $output == *"exec $STUB_DIR/warp-terminal"* ]]
}

@test "install_desktop_entry points Exec at the launcher" {
  in_apply 'install_desktop_entry /usr/local/bin/warp-terminal'
  [ "$status" -eq 0 ]
  run cat "$WARP_DESKTOP"
  [[ $output == *'Exec=env WARP_ENABLE_WAYLAND=1 /usr/local/bin/warp-terminal %U'* ]]
  [[ $output == *'StartupWMClass=dev.warp.Warp'* ]]
}

@test "ensure_starship_bashrc appends init when missing" {
  in_apply 'ensure_starship_bashrc "$WARP_BASHRC"'
  [ "$status" -eq 0 ]
  run cat "$WARP_BASHRC"
  [[ $output == *'existing bashrc'* ]]
  [[ $output == *'starship init bash'* ]]
}

@test "ensure_starship_bashrc is idempotent" {
  in_apply 'ensure_starship_bashrc "$WARP_BASHRC"'
  in_apply 'ensure_starship_bashrc "$WARP_BASHRC"'
  [ "$status" -eq 0 ]
  run grep -c 'starship init bash' "$WARP_BASHRC"
  [ "$output" = "1" ]
}

@test "ensure_starship_bashrc fails when the rc file is missing" {
  rm -f "$WARP_BASHRC"
  in_apply 'ensure_starship_bashrc "$WARP_BASHRC"'
  [ "$status" -ne 0 ]
}

@test "ensure_starship_bashrc keeps an existing init line untouched" {
  printf 'eval "$(starship init bash)"\n' >"$WARP_BASHRC"
  in_apply 'ensure_starship_bashrc "$WARP_BASHRC"'
  [ "$status" -eq 0 ]
  run grep -c 'added by devenv' "$WARP_BASHRC"
  [ "$output" = "0" ]
}

@test "apply_warp installs a Wayland launcher and desktop entry" {
  stub_warp_bin
  in_apply 'apply_warp'
  [ "$status" -eq 0 ]
  [ -x "$WARP_LAUNCHER" ]
  run cat "$WARP_LAUNCHER"
  [[ $output == *'WARP_ENABLE_WAYLAND='* ]]
  [ -f "$WARP_DESKTOP" ]
  run cat "$WARP_DESKTOP"
  [[ $output == *'WARP_ENABLE_WAYLAND=1'* ]]
}

@test "apply_warp wires up settings, shortcut, and prompt together" {
  stub_warp_bin
  stub_gsettings
  in_apply 'apply_warp'
  [ "$status" -eq 0 ]
  [[ $output == *'wrote Warp settings (Quake f12'* ]]
  [[ $output == *'bound GNOME shortcut F12 to Warp Quake'* ]]
  [[ $output == *'Starship init present'* ]]
  run cat "$GS_LOG"
  [[ $output == *'binding F12'* ]]
}

@test "apply_warp still writes settings when warp-terminal is missing" {
  in_apply 'warp_terminal_path() { return 1; }; apply_warp'
  [ "$status" -eq 0 ]
  [[ $output == *'is not on PATH'* ]]
  [ ! -e "$WARP_LAUNCHER" ]
  run cat "$WARP_SETTINGS"
  [[ $output == *'keybinding = "f12"'* ]]
}

@test "apply_warp reports when the GNOME shortcut cannot be installed" {
  stub_warp_bin
  in_apply 'apply_warp'
  [ "$status" -eq 0 ]
  [[ $output == *'GNOME shortcut not installed'* ]]
}

@test "apply_warp creates the config directory if it does not exist" {
  rm -rf "$WARP_CONFIG_DIR"
  in_apply 'apply_warp'
  [ "$status" -eq 0 ]
  [ -f "$WARP_SETTINGS" ]
}

@test "apply_warp is idempotent" {
  stub_warp_bin
  stub_gsettings
  in_apply 'apply_warp'
  in_apply 'apply_warp'
  [ "$status" -eq 0 ]
  run grep -c 'starship init bash' "$WARP_BASHRC"
  [ "$output" = "1" ]
  run grep -c '^# Managed by devenv' "$WARP_SETTINGS"
  [ "$output" = "1" ]
  run grep -c 'devenv-warp-quake' "$GS_STATE"
  [ "$output" = "1" ]
}

@test "sourcing apply-warp.sh changes nothing on its own" {
  stub_warp_bin
  rm -f "$WARP_SETTINGS"
  in_apply 'true'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$WARP_SETTINGS" ]
  [ ! -e "$WARP_LAUNCHER" ]
}
