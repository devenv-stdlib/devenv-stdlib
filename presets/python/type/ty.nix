{ lib, ... }:
{
  path = [
    "python"
    "type"
    "ty"
  ];
  description = "Astral ty type-checker hook when Python is on and pythonTypeChecker = ty.";
  when =
    cfg: ((cfg.languages.python or { }).enable or false) && ((cfg.pythonTypeChecker or "pyright") == "ty");
  project =
    { pkgs, ... }:
    {
      git-hooks.hooks.ty = {
        enable = true;
        name = "ty";
        description = "Astral ty type checker (beta)";
        package = pkgs.ty;
        entry = "${pkgs.ty}/bin/ty check";
        files = "\\.py$";
      };
    };
}
