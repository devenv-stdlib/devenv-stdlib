_: {
  # Plugins are a later TODO; this is just nvim on PATH.
  programs.neovim = {
    enable = true;
    # Adopt the 26.05 defaults now so providers are not pulled in unused.
    withRuby = false;
    withPython3 = false;
  };
}
