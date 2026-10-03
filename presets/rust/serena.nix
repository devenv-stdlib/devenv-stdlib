{ ... }:
{
  path = [
    "rust"
    "serena"
  ];
  description = "Serena rust language server when languages.rust.enable.";
  when = cfg: (cfg.languages.rust or { }).enable or false;
  project.stdlib.lang.rust.serena = [ "rust" ];
}
