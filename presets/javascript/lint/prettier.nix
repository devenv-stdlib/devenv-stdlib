# Thin tool preset: one prettier leaf for JS and TS.
_: {
  path = [
    "javascript"
    "lint"
    "prettier"
  ];
  description = "Prettier git-hook and JS/TS editor formatter settings.";
  when =
    cfg:
    ((cfg.languages.javascript or { }).enable or false)
    || ((cfg.languages.typescript or { }).enable or false);
  tools = [ "prettier" ];
}
