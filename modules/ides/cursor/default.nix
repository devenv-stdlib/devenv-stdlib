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
  # Specializes the VS Code sync: same packs, Cursor extension root.
  scripts.cursor-sync-extensions.exec = ides.mkSyncScript {
    extensionsDir = "$HOME/.cursor/extensions";
    logPrefix = "cursor";
  };

  enterShell = ''
    cursor-sync-extensions
  '';
}
