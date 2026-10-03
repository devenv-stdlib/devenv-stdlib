{ lib, ... }:
{
  path = [
    "javascript"
    "debtmap"
  ];
  description = "debtmap javascript language id when languages.javascript.enable.";
  when = cfg: (cfg.languages.javascript or { }).enable or false;
  project.stdlib.lang.javascript.debtmap = [ "javascript" ];
}
