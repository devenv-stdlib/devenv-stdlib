{ pkgs, ... }:
{
  # TOML CLI (lint/fmt/lsp). Cursor already ships even-better-toml for the editor.
  home.packages = [ pkgs.taplo ];
}
