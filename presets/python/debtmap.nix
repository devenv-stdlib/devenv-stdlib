_: {
  path = [
    "python"
    "debtmap"
  ];
  description = "debtmap python language id when languages.python.enable.";
  when = cfg: (cfg.languages.python or { }).enable or false;
  project.stdlib.lang.python.debtmap = [ "python" ];
}
