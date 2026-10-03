_: {
  path = [
    "python"
    "hooks"
    "sort-requirements-txt"
  ];
  description = "Sort requirements.txt in git-hooks when Python is on.";
  when = cfg: (cfg.languages.python or { }).enable or false;
  tools = [ "sort-requirements-txt" ];
}
