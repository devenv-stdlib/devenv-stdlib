{ lib, ... }:
{
  name = "serena-python";
  description = "Serena python language server when languages.python.enable.";
  when = cfg: (cfg.languages.python or { }).enable or false;
  project.stdlib.lang.python.serena = [ "python" ];
}
