_: {
  path = [
    "typescript"
    "debtmap"
  ];
  description = "debtmap typescript language id when languages.typescript.enable.";
  when = cfg: (cfg.languages.typescript or { }).enable or false;
  project.stdlib.lang.typescript.debtmap = [ "typescript" ];
}
