{
  pkgs,
  ...
}:
{
  home.packages = [ pkgs.nano ];

  # Same includes as NixOS programs.nano.syntaxHighlight: every syntax file
  # shipped with the package, including the extra/ set.
  xdg.configFile."nano/nanorc".text = ''
    include "${pkgs.nano}/share/nano/*.nanorc"
    include "${pkgs.nano}/share/nano/extra/*.nanorc"
  '';
}
