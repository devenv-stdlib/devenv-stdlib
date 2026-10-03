_: {
  path = [
    "python"
    "hooks"
    "sort-requirements-txt"
  ];
  description = "Sort requirements.txt in git-hooks when Python is on.";
  # when inherits python category policy (languages.python.enable or override).
  tools = [
    [
      "python"
      "sort-requirements-txt"
    ]
  ];
}
