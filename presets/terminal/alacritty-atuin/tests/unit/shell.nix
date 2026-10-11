{ lib, ... }:
let
  pe = import <devenv4monorepo/tests/lib/preset-eval.nix> { inherit lib; };
  inherit (pe)
    eval
    withBash
    sort
    shellLib
    ;
in
{
  testAlacrittyAtuinSingleShellOptionOptional = {
    expr =
      let
        ok =
          (eval (import <devenv4monorepo/presets/terminal/alacritty-atuin.nix>) withBash)
          .config.presets.terminal.alacritty-atuin;
        resolved = shellLib.resolve withBash ok.shell;
      in
      {
        inherit (ok.result) applied;
        tools = sort ok.result.includeTools;
        shellOption = ok.shell;
        inherit resolved;
        blesh = shellLib.shouldInstallBlesh resolved;
      };
    expected = {
      applied = true;
      tools = [
        "atuin"
        "bash"
        "blesh"
      ];
      shellOption = null;
      resolved = "bash";
      blesh = true;
    };
  };

  testAlacrittyAtuinMultiShellBleShOnlyBash = {
    expr =
      let
        multi = {
          tools.bash.enable = true;
          tools.zsh.enable = true;
        };
        onBash =
          (eval (import <devenv4monorepo/presets/terminal/alacritty-atuin.nix>) (
            multi // { presets.terminal.alacritty-atuin.shell = "bash"; }
          )).config.presets.terminal.alacritty-atuin.result;
        onZsh =
          (eval (import <devenv4monorepo/presets/terminal/alacritty-atuin.nix>) (
            multi // { presets.terminal.alacritty-atuin.shell = "zsh"; }
          )).config.presets.terminal.alacritty-atuin.result;
        missingShellExpr =
          (eval (import <devenv4monorepo/presets/terminal/alacritty-atuin.nix>) multi)
          .config.presets.terminal.alacritty-atuin.result;
        missingShell = builtins.tryEval missingShellExpr;
      in
      {
        bashTools = sort onBash.includeTools;
        zshTools = sort onZsh.includeTools;
        bashHasBlesh = builtins.elem "blesh" onBash.includeTools;
        zshHasBlesh = builtins.elem "blesh" onZsh.includeTools;
        mandatory = !missingShell.success;
      };
    expected = {
      bashTools = [
        "atuin"
        "bash"
        "blesh"
        "zsh"
      ];
      zshTools = [
        "atuin"
        "bash"
        "zsh"
      ];
      bashHasBlesh = true;
      zshHasBlesh = false;
      mandatory = true;
    };
  };

  testAlacrittyAtuinNoBashSkipsBlesh = {
    expr =
      let
        zshOnly = {
          tools.zsh.enable = true;
        };
        ok =
          (eval (import <devenv4monorepo/presets/terminal/alacritty-atuin.nix>) zshOnly)
          .config.presets.terminal.alacritty-atuin;
        resolved = shellLib.resolve zshOnly ok.shell;
      in
      {
        inherit (ok.result) applied;
        tools = sort ok.result.includeTools;
        inherit resolved;
        blesh = builtins.elem "blesh" ok.result.includeTools;
      };
    expected = {
      applied = true;
      tools = [
        "atuin"
        "zsh"
      ];
      resolved = "zsh";
      blesh = false;
    };
  };

  # stdlib.devenv.load passes `tools` and reads this declaration path.
  testAlacrittyAtuinIsPresetDeclaration = {
    expr =
      (import <devenv4monorepo/presets/terminal/alacritty-atuin.nix> {
        inherit lib;
        tools = { };
      }).path;
    expected = [
      "terminal"
      "alacritty-atuin"
    ];
  };
}
