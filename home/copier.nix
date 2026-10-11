{ pkgs, ... }:
{
  # User-global Copier CLI (kept for a future projects feature).
  # Package consumption is via the devenv-stdlib flake pin, not Copier.
  home.packages = [ pkgs.copier ];
}
