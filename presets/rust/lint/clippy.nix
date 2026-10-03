{ lib, ... }:
{
  path = [
    "rust"
    "lint"
    "clippy"
  ];
  description = "clippy git-hook when languages.rust.enable.";
  when = cfg: (cfg.languages.rust or { }).enable or false;
  project.git-hooks.hooks.clippy.enable = true;
}
