{ lib, ... }:
let
  categoryPolicy = import ../../../stdlib/category-policy.nix { inherit lib; };
  python = categoryPolicy.policies.python;
in
{
  path = [
    "python"
    "type"
    "pyright"
  ];
  description = "pyright git-hook when Python is available and pythonTypeChecker = pyright.";
  when = cfg: (python.available cfg) && ((cfg.pythonTypeChecker or "pyright") == "pyright");
  # Attrpath tools.python.lint.pyright (path list — avoids `with tools` shadowing `python`).
  tools = [
    [
      "python"
      "lint"
      "pyright"
    ]
  ];
}
