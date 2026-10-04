# Standalone Home Manager via den.homes (no NixOS/Darwin host required).
# Phase 4: sole HM composition root for supported Ubuntu hosts (`home-switch`).
# Supported platforms: x86_64 Linux (Ubuntu) only; aarch64 is not supported yet.
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

    # Template developer home — cursor + terminal + home-cli.
    # Language / project-ide aspects use the project class (see den/classes/project.nix).
    homes.x86_64-linux.developer = { };

    aspects.developer = {
      includes = [
        den.aspects.cursor
        den.aspects.terminal
        den.aspects.home-cli
      ];
      homeManager =
        { config, lib, ... }:
        let
          # Gitignored home.local.nix is invisible to pure flake eval. home-switch
          # always passes --impure so PWD-relative lookup works from the repo root.
          pwd = builtins.getEnv "PWD";
          pwdLocal = if pwd != "" then "${pwd}/home.local.nix" else null;
          localOverride =
            if pwdLocal != null && builtins.pathExists pwdLocal then
              pwdLocal
            else if builtins.pathExists ../home.local.nix then
              ../home.local.nix
            else
              null;
        in
        {
          imports = lib.optional (localOverride != null) localOverride;

          home = {
            # Prefer login-shell USER/HOME (needs --impure). Fixture fallback for eval.
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
                home.username / home.homeDirectory are empty. Run `home-switch` from a
                login shell (USER and HOME set), or set them in den/homes.nix /
                home.local.nix.
              '';
            }
          ];
        };
    };
  };
}
