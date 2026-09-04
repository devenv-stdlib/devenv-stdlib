_: {
  # enableAliases was removed; bash integration (default on) sets
  # ls/ll/la/lt/lla → eza. Do not alias cat (that is bat).
  programs.eza = {
    enable = true;
    enableBashIntegration = true;
  };
}
