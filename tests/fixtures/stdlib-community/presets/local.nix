{ stdlib, ... }:
stdlib.mkPreset {
  name = "local";
  description = "Fixture community preset";
  when = cfg: cfg.languages.python.enable or false;
  requires = [
    {
      assertion = true;
      message = "fixture";
    }
  ];
  tools = [ "project-only" ];
  includes = [ "python" ];
  configure = { };
}
