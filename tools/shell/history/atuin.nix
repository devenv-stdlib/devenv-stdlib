# Atuin shell history. ble.sh ordering stays in the blesh tool (mkBefore).
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
    tool = import ../../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "atuin";
      category = "shell.history";
      install = {
        kind = "hm-program";
        program = "atuin";
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
        homeManager =
          { lib, config, ... }:
          lib.mkIf (config.terminal.provider == "alacritty") {
            programs.atuin = {
              enable = true;
              enableBashIntegration = true;
              # User systemd + socket activation (generic Linux). Do not set
              # settings.daemon.autostart: it is incompatible with systemd_socket.
              daemon.enable = true;
              forceOverwriteSettings = true;
              settings.search_mode = "daemon-fuzzy";
            };
          };
      }
    )
