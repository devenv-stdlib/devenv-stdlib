# Atuin shell history. Integrations follow enabled shell tools; ble.sh stays bash-only.
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
    shell = import ../../../stdlib/shell.nix { inherit lib; };
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
        options.atuin.shell = shell.mkShellOption {
          description = "Shell Atuin integrates with when no shell tool is uniquely enabled. Same resolution as shell.preferred.";
        };
        homeManager =
          { lib, config, ... }:
          let
            resolved = shell.resolve config (
              if config.atuin.shell != null then config.atuin.shell else config.shell.preferred
            );
            shells = shell.policyShells config resolved;
            integrations = shell.enableIntegrations shells;
          in
          lib.mkIf (config.terminal.provider == "alacritty" && resolved != null) {
            assertions = [
              (shell.requireResolved {
                inherit config;
                value = if config.atuin.shell != null then config.atuin.shell else config.shell.preferred;
                message = "atuin.shell (or shell.preferred) is required unless exactly one of tools.{bash,zsh,elvish} is enabled";
              })
            ];

            programs.atuin = {
              enable = true;
              inherit (integrations) enableBashIntegration enableZshIntegration;
              # User systemd + socket activation (generic Linux). Do not set
              # settings.daemon.autostart: it is incompatible with systemd_socket.
              daemon.enable = true;
              forceOverwriteSettings = true;
              settings.search_mode = "daemon-fuzzy";
            };

            # Elvish: this HM pin has no programs.elvish. When elvish is among
            # policy shells, drop a snippet the user can `use` from rc.elv.
            xdg.configFile."elvish/lib/atuin.elv" = lib.mkIf (builtins.elem "elvish" shells) {
              text = ''
                eval (atuin init elvish | slurp)
              '';
            };
          };
      }
    )
