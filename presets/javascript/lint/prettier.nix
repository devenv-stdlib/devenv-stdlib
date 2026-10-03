# One prettier preset for JS and TS (shared hook + formatter settings).
_:
{
  path = [
    "javascript"
    "lint"
    "prettier"
  ];
  description = "Prettier git-hook and JS/TS editor formatter settings.";
  when =
    cfg:
    ((cfg.languages.javascript or { }).enable or false)
    || ((cfg.languages.typescript or { }).enable or false);
  project = {
    git-hooks.hooks.prettier = {
      enable = true;
      files = "\\.(cjs|js|jsx|mjs|ts|tsx)$";
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
}
