_: {
  path = [
    "python"
    "hooks"
    "check-python"
  ];
  description = "git-hooks check-python when languages.python.enable.";
  when = cfg: (cfg.languages.python or { }).enable or false;
  tools = [ "check-python" ];
}
