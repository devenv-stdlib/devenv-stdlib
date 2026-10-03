{ lib, ... }:
{
  name = "debtmap-go";
  description = "debtmap go language id when languages.go.enable.";
  when = cfg: (cfg.languages.go or { }).enable or false;
  project.stdlib.lang.go.debtmap = [ "go" ];
}
