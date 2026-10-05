# Local Prettier git-hook and JS/TS editor formatter wiring.
args@{
  pkgs,
  lib,
  config,
  ...
}:
if false then
  { inherit pkgs config; }
else
  let
    tool = import ../../../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "prettier";
      category = "lang.javascript.linters";
      # Shared with TypeScript — do not require languages.javascript.enable.
      categoryPolicy = "javascript-or-typescript";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project = {
        # treefmt prettier defaults also cover md/yaml/json; keep the former
        # git-hooks scope (JS/TS only) so yamlfmt / other formatters stay sole owners.
        treefmt.config = {
          programs.prettier.enable = true;
          # mkForce: treefmt-nix defaults also include md/yaml/json/css/html;
          # replace those so only JS/TS stay in scope (yamlfmt owns YAML).
          settings.formatter.prettier.includes = lib.mkForce [
            "*.cjs"
            "*.js"
            "*.jsx"
            "*.mjs"
            "*.ts"
            "*.tsx"
          ];
        };

        # Surface under javascript so merge order stays stable; settings are identical for TS.
        stdlib.lang.javascript.settings = {
          "[typescript]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
            "editor.formatOnSave" = true;
          };
          "[typescriptreact]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
            "editor.formatOnSave" = true;
          };
          "[javascript]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
            "editor.formatOnSave" = true;
          };
          "[javascriptreact]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
            "editor.formatOnSave" = true;
          };
        };
      };
    };
  in
  if args.__stdlibMeta or false then tool.meta spec else tool.applyLocal args spec
