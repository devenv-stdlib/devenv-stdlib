{
  pkgs,
  lib,
  config,
  ...
}:
let
  project = import ../lib/project.nix { inherit lib; };
  debtmapPkg = import ./pkg.nix { inherit pkgs lib; };
  languages = config.languages or { };
  on = project.debtmapLanguages languages != [ ];
in
{
  git-hooks.hooks.debtmap = {
    enable = on;
    name = "debtmap";
    description = "Analyze technical debt for enabled languages";
    package = debtmapPkg;
    entry = "${debtmapPkg}/bin/debtmap analyze . --no-tui --quiet";
    files = project.debtmapFiles languages;
    pass_filenames = false;
  };
}
