# Tool preset: Ruff lint + format hooks and editor formatter wiring.
_:
{
  path = [
    "python"
    "lint"
    "ruff"
  ];
  description = "Ruff lint/format hooks and Python editor formatter settings.";
  when = cfg: (cfg.languages.python or { }).enable or false;
  project = {
    git-hooks.hooks = {
      ruff.enable = true;
      ruff-format.enable = true;
    };

    stdlib.lang.python.settings = {
      "[python]" = {
        "editor.defaultFormatter" = "charliermarsh.ruff";
        "editor.formatOnSave" = true;
        "editor.codeActionsOnSave" = {
          "source.fixAll.ruff" = "explicit";
          "source.organizeImports.ruff" = "explicit";
        };
      };
    };
  };
}
