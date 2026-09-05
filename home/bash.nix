{ lib, ... }:
{
  # Keep programs.bash.enable so Starship, Atuin, direnv, fzf, zoxide, and
  # pay-respects still write their hooks. Redirect that generated file into
  # ~/.bashrc.d/ instead of replacing Ubuntu's ~/.bashrc.
  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
  };

  # Installer layout, not a hashed /nix/store/.../nix.sh. Honours NIX_STATE_DIR
  # and the XDG single-user profile. Host extras (Homebrew, pyenv) stay out of
  # this file — use home.local.nix or an unmanaged ~/.bashrc.d/*.sh.
  home = {
    file = {
      ".bashrc".target = ".bashrc.d/90-home-manager.sh";
      ".bashrc.d/00-nix.sh".text = ''
        _nix_state="''${NIX_STATE_DIR:-/nix/var/nix}"
        _nix_xdg="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile/etc/profile.d/nix.sh"
        if [ -e "$_nix_state/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
          . "$_nix_state/profiles/default/etc/profile.d/nix-daemon.sh"
        elif [ -e "$_nix_state/profiles/default/etc/profile.d/nix.sh" ]; then
          . "$_nix_state/profiles/default/etc/profile.d/nix.sh"
        elif [ -e "$_nix_xdg" ]; then
          . "$_nix_xdg"
        elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
          . "$HOME/.nix-profile/etc/profile.d/nix.sh"
        fi
        unset _nix_state _nix_xdg
      '';
    };
    activation.ensureBashrcD = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      bash ${./ensure-bashrc-d.sh} "$HOME/.bashrc" /etc/skel/.bashrc
    '';
  };
}
