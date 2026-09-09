{
  pkgs,
  lib,
  config,
  ...
}:
let
  project = import ../lib/project.nix { inherit lib; };
  nonNix = import ../non-nix/lib.nix { inherit lib; };
  debtmapEntry = nonNix.resolvedByName pkgs "debtmap";
  debtmapPkg =
    if debtmapEntry != null && debtmapEntry.via == "nix" then
      debtmapEntry.package
    else
      pkgs.writeShellScriptBin "debtmap" ''
        exec ${lib.getExe pkgs.mise} exec -- debtmap "$@"
      '';
  languages = config.languages or { };
  on = project.debtmapLanguages languages != [ ];
in
{
  git-hooks.hooks.debtmap = {
    enable = on;
    name = "debtmap";
    description = "Analyze technical debt for enabled languages";
    package = debtmapPkg;
    entry = "${lib.getExe debtmapPkg} analyze . --no-tui --quiet";
    files = project.debtmapFiles languages;
    pass_filenames = false;
  };
}
