# JS and TS share the Serena typescript server (lib.unique in the loader).
{ ... }:
{
  path = [
    "javascript"
    "serena"
  ];
  description = "Serena typescript language server when JS or TS is on.";
  when =
    cfg:
    ((cfg.languages.javascript or { }).enable or false)
    || ((cfg.languages.typescript or { }).enable or false);
  project.stdlib.lang.javascript.serena = [ "typescript" ];
}
