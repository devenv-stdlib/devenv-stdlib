{ pkgs, ... }:
{
  # nixpkgs has no explainshell (idank/explainshell web app; #181905 never
  # landed). tealdeer is the closest maintained CLI: `tldr` examples.
  home.packages = [ pkgs.tealdeer ];
}
