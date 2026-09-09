{
  pkgs,
  lib,
  config,
  ...
}:
let
  ext = import ./ext-lib.nix { inherit pkgs; };
  link = e: {
    name = ".vscode/extensions/${ext.id e}";
    value.source = ext.root e;
  };
in
{
  # Common extensions only. Users may add more under ~/.vscode/extensions.
  config = lib.mkIf config.vscode.enable {
    home.file = builtins.listToAttrs (map link ext.common);
  };
}
