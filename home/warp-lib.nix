{ lib }:
let
  modifier = {
    ctrl = "<Ctrl>";
    control = "<Ctrl>";
    alt = "<Alt>";
    opt = "<Alt>";
    option = "<Alt>";
    shift = "<Shift>";
    super = "<Super>";
    cmd = "<Super>";
    win = "<Super>";
    meta = "<Super>";
    enter = "Return";
    return = "Return";
    space = "space";
    tab = "Tab";
    grave = "grave";
    "`" = "grave";
    backquote = "grave";
    esc = "Escape";
    escape = "Escape";
  };

  mapToken =
    token:
    if token == "" then
      throw "warp: empty token in quakeKeybinding"
    else
      modifier.${token} or (if builtins.match "f[0-9]+" token != null then lib.toUpper token else token);
in
{
  mkPackage = pkgs: pkgs.warp-terminal.override { waylandSupport = true; };

  gnomeShortcutId = "devenv-warp-quake";

  gnomeShortcutPath = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/devenv-warp-quake/";

  toGnomeBinding =
    spec:
    let
      lowered = lib.toLower spec;
    in
    if lowered == "" then
      throw "warp: quakeKeybinding must not be empty"
    else
      lib.concatMapStrings mapToken (lib.splitString "-" lowered);

  settingsToml =
    keybinding: extra:
    ''
      # Managed by Home Manager (home/warp.nix). Extra tables: warp.extraSettings.

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
    ''
    + extra;
}
