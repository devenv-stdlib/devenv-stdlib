# Thin tool preset: enable local mkTool `ruff` when Python is on.
# when inherits python category policy (languages.python.enable or override).
_: {
  path = [
    "python"
    "lint"
    "ruff"
  ];
  description = "Ruff lint/format hooks and Python editor formatter settings.";
  tools = [ "ruff" ];
}
