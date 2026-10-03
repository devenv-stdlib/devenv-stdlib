# Thin tool preset: enable local mkTool `python.lint.ruff` when Python is on.
# when inherits python category policy (languages.python.enable or override).
# tools= takes attrpath segments (same identity as tools.python.lint.ruff).
_: {
  path = [
    "python"
    "lint"
    "ruff"
  ];
  description = "Ruff lint/format hooks and Python editor formatter settings.";
  tools = [
    [
      "python"
      "lint"
      "ruff"
    ]
  ];
}
