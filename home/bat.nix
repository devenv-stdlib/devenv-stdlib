_: {
  programs.bat.enable = true;

  # programs.bat does not alias cat; keep the usual muscle memory.
  programs.bash.shellAliases.cat = "bat";
}
