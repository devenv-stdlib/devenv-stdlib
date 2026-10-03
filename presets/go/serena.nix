{ ... }:
{
  path = [
    "go"
    "serena"
  ];
  description = "Serena go language server when languages.go.enable.";
  when = cfg: (cfg.languages.go or { }).enable or false;
  project.stdlib.lang.go.serena = [ "go" ];
}
