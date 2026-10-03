# Warp terminal package (Wayland override), settings, and Quake keybinding.
args@{
  pkgs,
  lib,
  config,
  ...
}:
# pkgs and config stay in the signature so Den does not call this without pkgs.
# The false branch is never evaluated; it only marks those names as used.
if false then
  { inherit pkgs config; }
else
  let
    tool = import ../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "warp";
      category = "terminal";
      install = {
        kind = "nix";
        attr = "warp-terminal";
      };
      upgrade = "flake";
      defaultEnable = true;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.apply args (
      spec
      // {
        options.warp.extraSettings = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = ''
            Extra TOML appended to `~/.config/warp-terminal/settings.toml`. Use this
            rather than Warp's settings UI: the file is Home Manager-owned, so the
            UI's writes are lost on the next switch.
          '';
        };

        homeManager =
          {
            pkgs,
            lib,
            config,
            ...
          }:
          let
            terminalLib = import ../../home/terminal-lib.nix { inherit lib; };
            warp-terminal = terminalLib.warpPackage pkgs;
            warpExe = lib.getExe warp-terminal;
            desktopId = terminalLib.desktopIds.warp;
            # Packaged as dev.warp.Warp.png, not warp-terminal. Absolute path so the
            # Ubuntu dock does not need hicolor lookup through the Nix profile.
            warpIcon = "${warp-terminal}/share/icons/hicolor/512x512/apps/dev.warp.Warp.png";
          in
          lib.mkIf (config.terminal.provider == "warp") {
            nixpkgs.config.allowUnfree = true;

            home = {
              packages = [ warp-terminal ];
              sessionVariables.WARP_ENABLE_WAYLAND = "1";
            };

            xdg = {
              configFile."warp-terminal/settings.toml" = {
                text = terminalLib.warpSettingsToml {
                  inherit (config.terminal) heightPercent;
                  keybinding = config.terminal.quakeKeybinding;
                  extra = config.warp.extraSettings;
                };
                force = true;
              };

              dataFile."applications/${desktopId}".text = terminalLib.mkDesktopEntry {
                name = "Warp";
                comment = "Warp terminal with Wayland and Quake mode";
                exec = "env WARP_ENABLE_WAYLAND=1 ${warpExe} %U";
                icon = warpIcon;
                wmClass = "dev.warp.Warp";
              };
            };

            # Warp cannot register a global hotkey on Wayland, so GNOME launches it and
            # Warp's own dedicated-window setting takes over from there.
            dconf.settings."org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${terminalLib.warpShortcutId}" =
              {
                name = "Warp Quake";
                command = warpExe;
                binding = terminalLib.toGnomeBinding config.terminal.quakeKeybinding;
              };
          };
      }
    )
