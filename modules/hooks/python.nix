{
  pkgs,
  config,
  ...
}:
let
  on = (config.languages.python or { }).enable or false;
  checker = config.pythonTypeChecker or "pyright";
in
{
  git-hooks.hooks = {
    ruff.enable = on;
    ruff-format.enable = on;
    check-python.enable = on;
    python-debug-statements.enable = on;
    sort-requirements-txt.enable = on;
    pyright.enable = on && checker == "pyright";
    ty = {
      enable = on && checker == "ty";
      name = "ty";
      description = "Astral ty type checker (beta)";
      package = pkgs.ty;
      entry = "${pkgs.ty}/bin/ty check";
      files = "\\.py$";
    };
  };
}
