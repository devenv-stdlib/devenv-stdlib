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
    "ty"
  ];
  description = "Astral ty type-checker hook when Python is available and pythonTypeChecker = ty.";
  when = cfg: (pythonPolicy.available cfg) && ((cfg.pythonTypeChecker or "pyright") == "ty");
  tools = [ tools.python.lint.ty ];
}
