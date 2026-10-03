{ lib, ... }:
{
  path = [
    "go"
    "lint"
    "golangci-lint"
  ];
  description = "golangci-lint git-hook when languages.go.enable.";
  when = cfg: (cfg.languages.go or { }).enable or false;
  project.git-hooks.hooks.golangci-lint.enable = true;
}
