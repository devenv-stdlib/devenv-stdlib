# Standalone Home Manager via den.homes (no NixOS/Darwin host required).
{ inputs, den, ... }:
{
  imports = [ inputs.den.flakeModule ];

  den = {
    default.homeManager = {
      home.stateVersion = "25.05";
      # Ubuntu / other non-NixOS: export session vars and XDG dirs to GNOME.
      targets.genericLinux.enable = true;
      programs.home-manager.enable = true;
      nixpkgs.config.allowUnfree = true;
    };

    # Template developer home — cursor (Phase 1) + terminal (Phase 2).
    # Language / project-ide aspects are project-scoped (no HM class yet).
    homes.x86_64-linux.developer = { };

    aspects.developer = {
      includes = [
        den.aspects.cursor
        den.aspects.terminal
      ];
      homeManager =
        { config, lib, ... }:
        {
          home = {
            # Match legacy home.nix: prefer login-shell USER/HOME (needs --impure).
            username = lib.mkDefault (
              let
                u = builtins.getEnv "USER";
              in
              if u != "" then u else "developer"
            );
            homeDirectory = lib.mkDefault (
              let
                h = builtins.getEnv "HOME";
              in
              if h != "" then h else "/home/developer"
            );
          };

          assertions = [
            {
              assertion = config.home.username != "" && config.home.homeDirectory != "";
              message = ''
                home.username / home.homeDirectory are empty. Run `home-switch-den` from a
                login shell (USER and HOME set), or set them in den/homes.nix.
              '';
            }
          ];
        };
    };
  };
}
