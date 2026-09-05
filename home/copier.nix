{ pkgs, ... }:
{
  # User-global CLI so monorepos can `copier copy` / `copier update`
  # this template without entering devenv shell.
  home.packages = [ pkgs.copier ];
}
