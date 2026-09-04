_: {
  # nixpkgs removed thefuck; pay-respects is the HM replacement.
  # --alias fuck keeps the same command the old bashrc used.
  programs.pay-respects = {
    enable = true;
    enableBashIntegration = true;
    options = [
      "--alias"
      "fuck"
    ];
  };
}
