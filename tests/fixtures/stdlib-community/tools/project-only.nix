{ stdlib, ... }:
stdlib.mkTool {
  name = "project-only";
  category = "lang.python.linters";
  install = {
    type = "catalog";
    name = "ruff";
  };
  upgrade = "catalog";
  project = { };
}
