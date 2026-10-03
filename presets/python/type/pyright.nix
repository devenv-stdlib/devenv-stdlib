_: {
  path = [
    "python"
    "type"
    "pyright"
  ];
  description = "pyright git-hook when Python is on and pythonTypeChecker = pyright.";
  when =
    cfg:
    ((cfg.languages.python or { }).enable or false)
    && ((cfg.pythonTypeChecker or "pyright") == "pyright");
  tools = [ "pyright" ];
}
