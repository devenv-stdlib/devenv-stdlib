# Explicit when + requires for strict/warn API coverage (no category policy).
_: {
  path = [
    "demo"
    "strict-gate"
  ];
  description = "Mock preset with leaf requires and explicit when.";
  categoryPolicy = false;
  when = cfg: (cfg.demo or { }).enable or false;
  requires = [
    {
      assertion = cfg: (cfg.demo or { }).token or null != null;
      message = "demo.strict-gate requires demo.token when demo.enable is set";
    }
  ];
  project = { };
}
