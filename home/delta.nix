{
  # home-switch -b backup keeps the previous ~/.gitconfig as
  # ~/.gitconfig.backup. Set userName / userEmail in home.local.nix.
  programs.git = {
    enable = true;
    delta.enable = true;
  };
}
