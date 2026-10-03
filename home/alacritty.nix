# Shim. Implementation: tools/terminal/alacritty.nix and its siblings.
{
  imports = [
    ../tools/terminal/alacritty.nix
    ../tools/terminal/mux/zellij.nix
    ../tools/shell/history/atuin.nix
    ../tools/shell/completion/blesh.nix
  ];
}
