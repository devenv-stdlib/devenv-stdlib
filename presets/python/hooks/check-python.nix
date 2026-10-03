{ tools, ... }: {
  path = [
    "python"
    "hooks"
    "check-python"
  ];
  description = "git-hooks check-python when languages.python.enable.";
  # when inherits python category policy (languages.python.enable or override).
  tools = with tools; [ python.check-python ];
}
