{ pkgs, ... }:
let
  # Community cheats (global). Repo-local sheets live in $DEVENV_ROOT/cheats
  # and are prepended in devenv enterShell via NAVI_PATH.
  communityCheats = pkgs.fetchFromGitHub {
    owner = "denisidoro";
    repo = "cheats";
    rev = "1339965e9615ce00174cc308a41279d9c59aa75f";
    hash = "sha256-wPsAazAGKPhu0MZfZbZ0POUBEMg95frClAQERTDFXUg=";
  };
in
{
  home.sessionVariables.NAVI_PATH = "${communityCheats}";
}
