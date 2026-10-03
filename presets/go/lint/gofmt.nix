_: {
  path = [
    "go"
    "lint"
    "gofmt"
  ];
  description = "gofmt git-hook when languages.go.enable.";
  when = cfg: (cfg.languages.go or { }).enable or false;
  tools = [ "gofmt" ];
}
