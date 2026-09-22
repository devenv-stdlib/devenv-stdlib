{
  pkgs,
  lib,
  config,
  ...
}:
let
  ides = import ../lib.nix { inherit pkgs lib config; };
in
{
  # Regenerated on devenv:files from languages.*. Do not edit by hand.
  # Recommendations only; users may install other extensions freely.
  files.".vscode/extensions.json".json = {
    inherit (ides) recommendations unwantedRecommendations;
  };

  # Language packs for VS Code when the user opts into the app (HM).
  scripts.vscode-sync-extensions.exec = ides.mkSyncScript {
    extensionsDir = "$HOME/.vscode/extensions";
  };
}
