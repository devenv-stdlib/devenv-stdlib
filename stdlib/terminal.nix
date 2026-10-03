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
      throw "terminal: empty token in quakeKeybinding"
    else
      modifier.${token} or (if builtins.match "f[0-9]+" token != null then lib.toUpper token else token);
in
{
  # Both providers take their shortcut from terminal.quakeKeybinding, and both
  # ultimately register it with GNOME, so the accelerator mapping is shared.
  toGnomeBinding =
    spec:
    let
      lowered = lib.toLower spec;
    in
    if lowered == "" then
      throw "terminal: quakeKeybinding must not be empty"
    else
      lib.concatMapStrings mapToken (lib.splitString "-" lowered);

  # Dash pins desktopIds.${provider}. alacrittyQuake is only for the GNOME
  # extension (F12); it is never the sidebar icon, and is removed from the
  # dash if it ever lands there.
  desktopIds = {
    alacritty = "dev.devenv.AlacrittyZellij.desktop";
    alacrittyQuake = "dev.devenv.AlacrittyZellijQuake.desktop";
    warp = "dev.warp.Warp.desktop";
  };

  quakeExtensionUuid = "quake-terminal@diegodario88.github.io";

  # Written straight to ~/.local/share/applications rather than through
  # xdg.desktopEntries: that installs into the Nix profile, and gnome-shell
  # usually starts without ~/.nix-profile/share on XDG_DATA_DIRS.
  mkDesktopEntry =
    {
      name,
      comment,
      exec,
      icon,
      wmClass,
      noDisplay ? false,
    }:
    ''
      [Desktop Entry]
      Type=Application
      Name=${name}
      GenericName=Terminal Emulator
      Comment=${comment}
      Exec=${exec}
      Icon=${icon}
      Terminal=false
      Categories=System;TerminalEmulator;
      StartupWMClass=${wmClass}
      Keywords=shell;prompt;command;commandline;cmd;
      ${lib.optionalString noDisplay "NoDisplay=true"}
    '';

  warpPackage = pkgs: pkgs.warp-terminal.override { waylandSupport = true; };

  warpShortcutId = "devenv-warp-quake";

  warpShortcutPath = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/devenv-warp-quake/";

  warpSettingsToml =
    {
      keybinding,
      heightPercent,
      extra,
    }:
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
      height = ${toString heightPercent}
    ''
    + extra;
}
