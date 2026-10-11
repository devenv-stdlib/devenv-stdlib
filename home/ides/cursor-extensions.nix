{
  pkgs,
  lib,
  config,
  ...
}:
let
  ext = import ../../stdlib/ide-ext.nix { inherit pkgs; };
  link = e: {
    name = ".cursor/extensions/${ext.id e}";
    value.source = ext.root e;
  };
in
{
  config = lib.mkIf config.cursor.enable {
    home.file = builtins.listToAttrs (map link ext.common);
  };
}
