# Thin tool preset: enable local mkTool `ruff` when Python is on.
_: {
  path = [
    "python"
    "lint"
    "ruff"
  ];
  description = "Ruff lint/format hooks and Python editor formatter settings.";
  when = cfg: (cfg.languages.python or { }).enable or false;
  tools = [ "ruff" ];
}
