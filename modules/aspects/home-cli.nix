# Remaining HM modules not owned by cursor/terminal aspects (developer home).
# Cursor stack + terminal/provider stay in their aspects (avoid double-enable).
{
  den,
  lib,
  inputs,
  ...
}:
{
  den.aspects.home-cli = {
    # Cache tools are opt-in via tools.*.enable (tool-leaf aspects).
    # presets.cache.* for home.local.nix is an HM module (home/cache-presets.nix):
    # Den mkPreset aspects cannot see home.local.nix (imported later inside HM).
    includes = [
      den.aspects.mr-boxington
      den.aspects.build-cleaner
    ];

    homeManager = {
      imports = [
        # Shared preferred-shell option for shell tools (atuin, blesh, starship).
        (import ../../stdlib/shell.nix { inherit lib; }).hmModule
        # Opt-in cache presets from home.local.nix → tools.*.enable.
        ../../home/cache-presets.nix
        ../../home/bash.nix
        # IDEs not on the cursor cascade (cursor*/mise stay in cursor aspects).
        ../../home/ides/vscode.nix
        # nixvim HM module (flake input). tools/ide/neovim.nix enables programs.nixvim.
        inputs.nixvim.homeModules.nixvim
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
