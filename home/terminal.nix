{
  pkgs,
  lib,
  config,
  ...
}:
let
  terminalLib = import ./terminal-lib.nix { inherit lib; };
  cfg = config.terminal;

  activeDesktopId = terminalLib.desktopIds.${cfg.provider};
  staleDesktopIds = lib.attrValues (
    lib.filterAttrs (provider: _: provider != cfg.provider) terminalLib.desktopIds
  );

  gsettingsList = "${lib.getExe pkgs.python3} ${./gsettings-list.py}";
  quakeExtensionFlag = if cfg.provider == "alacritty" then "--add" else "--remove";
in
{
  imports = [
    ./alacritty.nix
    ./warp.nix
    ../tools/shell/prompt/starship.nix
  ];

  options.terminal = {
    provider = lib.mkOption {
      type = lib.types.enum [
        "alacritty"
        "warp"
      ];
      default = "alacritty";
      description = ''
        Which terminal to install and bind to the Quake shortcut.

        `alacritty` drops down Alacritty running Zellij through the
        quake-terminal GNOME extension. It renders under VMware and other
        virtual GPUs, which is why it is the default.

        `warp` installs Warp and uses its own dedicated hotkey window.

        Only the selected provider is installed; switching also clears the
        other one's GNOME shortcut, dash icon, and desktop entry.
      '';
    };

    quakeKeybinding = lib.mkOption {
      type = lib.types.str;
      default = "f12";
      description = ''
        Quake shortcut, written as modifiers and a key joined by `-`, for
        example f12, ctrl-`, or alt-enter. Override from home.local.nix:

          { terminal.quakeKeybinding = "ctrl-`"; }
      '';
    };

    heightPercent = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 30;
      description = ''
        How much of the screen height the dropped-down terminal covers. Both
        providers pin it to the top edge at full width.
      '';
    };

    pinToGnomeDash = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Append the active terminal to the GNOME dash (Ubuntu sidebar) without
        replacing the rest of `favorite-apps`.
      '';
    };

    gnomeExtraCustomKeybindings = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra GNOME `custom-keybindings` paths to keep. Home Manager replaces
        that array, so list any other shortcuts here.
      '';
    };
  };

  config = {
    # Home Manager replaces this array wholesale. Listing only the active
    # provider's shortcut is what stops a stale Warp binding from fighting the
    # Quake extension over the same key after a switch.
    dconf.settings."org/gnome/settings-daemon/plugins/media-keys".custom-keybindings =
      lib.optional (cfg.provider == "warp") terminalLib.warpShortcutPath
      ++ cfg.gnomeExtraCustomKeybindings;

    # favorite-apps and enabled-extensions belong to the user, not to us, so
    # they are edited in place instead of being declared in dconf.settings.
    # Use the host gsettings: devenv's PATH often omits /usr/bin, and Nix
    # glib does not ship org.gnome.shell schemas. Needs the session bus.
    home.activation.syncGnomeTerminalLists = lib.hm.dag.entryAfter [ "dconfSettings" ] ''
      export PATH="/usr/bin:/bin:$PATH"
      if ! command -v gsettings >/dev/null 2>&1; then
        echo "home/terminal.nix: gsettings not found; skip dash/extension sync" >&2
      elif [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        echo "home/terminal.nix: no session bus; skip dash/extension sync" >&2
      else
        ${lib.optionalString cfg.pinToGnomeDash ''
          ${gsettingsList} org.gnome.shell favorite-apps \
            --add ${activeDesktopId} \
            ${lib.concatMapStringsSep " " (id: "--remove ${id}") staleDesktopIds}
        ''}
        ${gsettingsList} org.gnome.shell enabled-extensions \
          ${quakeExtensionFlag} ${terminalLib.quakeExtensionUuid}
      fi
    '';
  };
}
