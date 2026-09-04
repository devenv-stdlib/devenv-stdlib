{
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    # Atuin already owns Ctrl-R in Alacritty bash.
    historyWidget.command = "";
  };
}
