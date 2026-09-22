# Phase 3 dual-run: remaining legacy home.nix modules not owned by cursor/terminal.
# Keeps Den homeConfiguration on parity with -f home.nix for the developer fixture.
# Cursor stack + terminal/provider stay in their aspects (avoid double-enable churn).
_: {
  den.aspects.home-cli = {
    includes = [ ];

    homeManager = {
      imports = [
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
