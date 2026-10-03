_: {
  path = [
    "python"
    "hooks"
    "debug-statements"
  ];
  description = "Reject Python debug leftovers in git-hooks.";
  when = cfg: (cfg.languages.python or { }).enable or false;
  tools = [ "debug-statements" ];
}
