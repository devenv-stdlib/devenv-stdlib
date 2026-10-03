_: {
  path = [
    "python"
    "hooks"
    "debug-statements"
  ];
  description = "Reject Python debug leftovers in git-hooks.";
  # when inherits python category policy (languages.python.enable or override).
  tools = [
    [
      "python"
      "debug-statements"
    ]
  ];
}
