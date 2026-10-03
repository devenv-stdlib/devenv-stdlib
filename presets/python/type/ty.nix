{ lib, ... }:
let
  categoryPolicy = import ../../../stdlib/category-policy.nix { inherit lib; };
  python = categoryPolicy.policies.python;
in
{
  path = [
    "python"
    "type"
    "ty"
  ];
  description = "Astral ty type-checker hook when Python is available and pythonTypeChecker = ty.";
  when = cfg: (python.available cfg) && ((cfg.pythonTypeChecker or "pyright") == "ty");
  # Attrpath tools.python.lint.ty (path list — avoids `with tools` shadowing `python`).
  tools = [
    [
      "python"
      "lint"
      "ty"
    ]
  ];
}
