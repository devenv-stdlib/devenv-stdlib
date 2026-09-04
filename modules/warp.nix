{
  pkgs,
  lib,
  config,
  ...
}:
let
  # waylandSupport wraps the binary with WARP_ENABLE_WAYLAND=1 and adds
  # libwayland to the rpath. The env var is also exported below so any
  # launcher that does not go through the wrapper still gets Wayland.
  warp-terminal = pkgs.warp-terminal.override { waylandSupport = true; };
in
{
  options.warp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Warp and apply Quake mode plus Starship settings.";
    };

    quakeKeybinding = lib.mkOption {
      type = lib.types.str;
      default = "f12";
      description = ''
        Quake-mode shortcut in Warp settings.toml form (modifiers and a key
        joined by `-`, for example f12, ctrl-`, or alt-enter).
        Override from devenv.local.nix:

          { warp.quakeKeybinding = "ctrl-`"; }
      '';
    };
  };

  config = lib.mkIf config.warp.enable {
    packages = [
      warp-terminal
      pkgs.starship
    ];

    env.WARP_ENABLE_WAYLAND = "1";
    env.WARP_QUAKE_KEYBINDING = config.warp.quakeKeybinding;

    enterShell = ''
      if [ -x "$DEVENV_ROOT/scripts/apply-warp.sh" ]; then
        "$DEVENV_ROOT/scripts/apply-warp.sh" || printf 'warp: apply-warp.sh failed (continuing)\n' >&2
      fi
    '';
  };
}
