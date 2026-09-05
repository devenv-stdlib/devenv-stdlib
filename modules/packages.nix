{
  pkgs,
  lib,
  config,
  ...
}:
{
  packages = [
    pkgs.git
    pkgs.gh
    pkgs.jq
    pkgs.ripgrep
    pkgs.fd
    pkgs.direnv
    pkgs.nixfmt
    pkgs.bats
    pkgs.shellcheck
    pkgs.home-manager
    pkgs.commitlint
    pkgs.copier
    (import ./debtmap-pkg.nix { inherit pkgs lib; })
  ]
  ++ lib.optional config.services.redis.enable pkgs.iredis;
}
