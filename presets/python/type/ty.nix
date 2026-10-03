_: {
  path = [
    "python"
    "type"
    "ty"
  ];
  description = "Astral ty type-checker hook when Python is on and pythonTypeChecker = ty.";
  when =
    cfg:
    ((cfg.languages.python or { }).enable or false) && ((cfg.pythonTypeChecker or "pyright") == "ty");
  tools = [ "ty" ];
}
