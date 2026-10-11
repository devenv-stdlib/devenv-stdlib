# Shim. Implementation: tools/ide/neovim.nix (nixvim-backed programs.nixvim).
# The nixvim Home Manager module itself is imported by modules/aspects/home-cli.nix
# from inputs.nixvim.homeModules.nixvim (Den has flake inputs; HM modules do not).
{
  imports = [ ../../tools/ide/neovim.nix ];
}
