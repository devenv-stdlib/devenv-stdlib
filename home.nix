{
  config,
  lib,
  ...
}:
{
  imports = [
    ./home/bash.nix
    ./home/terminal.nix
    ./home/ides
    ./home/mise.nix
    ./home/llm-context.nix
    ./home/bat.nix
    ./home/eza.nix
    ./home/copier.nix
    ./home/httpie.nix
    ./home/explainshell.nix
    ./home/navi.nix
    ./home/taplo.nix
    ./home/semantic-release.nix
    ./home/pay-respects.nix
    ./home/usql.nix
    ./home/zoxide.nix
    ./home/act.nix
    ./home/docker.nix
    ./home/fzf.nix
    ./home/delta.nix
    ./home/direnv.nix
    ./home/ripgrep.nix
    ./home/fd.nix
    ./home/gh.nix
  ]
  ++ lib.optional (builtins.pathExists ./home/copier-llm.nix) ./home/copier-llm.nix
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
