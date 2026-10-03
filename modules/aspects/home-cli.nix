# Remaining HM modules not owned by cursor/terminal aspects (developer home).
# Cursor stack + terminal/provider stay in their aspects (avoid double-enable).
{ lib, ... }:
{
  den.aspects.home-cli = {
    includes = [ ];

    homeManager = {
      imports = [
        # Shared preferred-shell option for shell tools (atuin, blesh, starship).
        (import ../../stdlib/shell.nix { inherit lib; }).hmModule
        ../../home/bash.nix
        # IDEs not on the cursor cascade (cursor*/mise stay in cursor aspects).
        ../../home/ides/vscode.nix
        ../../home/ides/neovim.nix
        ../../home/ides/nano.nix
        # mise also imported by cursor-llm; same-path re-import is fine.
        ../../home/mise.nix
        ../../home/bat.nix
        ../../home/eza.nix
        ../../home/copier.nix
        ../../home/httpie.nix
        ../../home/explainshell.nix
        ../../home/navi.nix
        ../../home/taplo.nix
        ../../home/semantic-release.nix
        ../../home/pay-respects.nix
        ../../home/usql.nix
        ../../home/zoxide.nix
        ../../home/act.nix
        ../../home/docker.nix
        ../../home/fzf.nix
        ../../home/delta.nix
        ../../home/direnv.nix
        ../../home/ripgrep.nix
        ../../home/fd.nix
        ../../home/gh.nix
      ];
    };
  };
}
