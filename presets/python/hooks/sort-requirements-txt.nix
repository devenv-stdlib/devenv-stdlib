{ lib, ... }:
{
  path = [
    "python"
    "hooks"
    "sort-requirements-txt"
  ];
  description = "Sort requirements.txt in git-hooks when Python is on.";
  when = cfg: (cfg.languages.python or { }).enable or false;
  project.git-hooks.hooks.sort-requirements-txt.enable = true;
}
