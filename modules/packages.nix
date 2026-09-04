{ pkgs, ... }:
{
  packages = [
    pkgs.git
    pkgs.gh
    pkgs.jq
    pkgs.ripgrep
    pkgs.fd
    pkgs.direnv
    pkgs.nixfmt-rfc-style
    pkgs.bats
    pkgs.shellcheck
    pkgs.home-manager
  ];
}
