{ lib, tools, ... }:
let
  categoryPolicy = import ../../../stdlib/category-policy.nix { inherit lib; };
  # Named pythonPolicy so `tools.python…` is not shadowed by a `python` binding.
  pythonPolicy = categoryPolicy.policies.python;
in
{
  path = [
    "python"
    "type"
    "pyright"
  ];
  description = "pyright git-hook when Python is available and pythonTypeChecker = pyright.";
  when = cfg: (pythonPolicy.available cfg) && ((cfg.pythonTypeChecker or "pyright") == "pyright");
  tools = [ tools.python.lint.pyright ];
}
