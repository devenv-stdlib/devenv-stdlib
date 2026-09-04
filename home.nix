{
  config,
  lib,
  ...
}:
{
  imports = [
    ./home/terminal.nix
    ./home/cursor.nix
    ./home/nano.nix
    ./home/pay-respects.nix
  ]
  ++ lib.optional (builtins.pathExists ./home.local.nix) ./home.local.nix;

  home = {
    username = lib.mkDefault (builtins.getEnv "USER");
    homeDirectory = lib.mkDefault (builtins.getEnv "HOME");
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;

  # Ubuntu / other non-NixOS: export session vars and XDG dirs to GNOME.
  targets.genericLinux.enable = true;

  assertions = [
    {
      assertion = config.home.username != "" && config.home.homeDirectory != "";
      message = ''
        home.username / home.homeDirectory are empty. Run `home-switch` from a
        login shell (USER and HOME set), or copy home.local.nix.example to
        home.local.nix and set them there.
      '';
    }
  ];
}
