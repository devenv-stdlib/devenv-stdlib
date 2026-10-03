{ lib, ... }:
{
  name = "debtmap-rust";
  description = "debtmap rust language id when languages.rust.enable.";
  when = cfg: (cfg.languages.rust or { }).enable or false;
  project.stdlib.lang.rust.debtmap = [ "rust" ];
}
