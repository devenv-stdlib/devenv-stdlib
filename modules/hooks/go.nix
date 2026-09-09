{ config, ... }:
let
  on = (config.languages.go or { }).enable or false;
in
{
  git-hooks.hooks = {
    gofmt.enable = on;
    golangci-lint.enable = on;
  };
}
