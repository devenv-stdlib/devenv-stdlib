_:
{
  path = [
    "rust"
    "lint"
    "rustfmt"
  ];
  description = "rustfmt git-hook and edition-aware editor args when Rust is on.";
  when = cfg: (cfg.languages.rust or { }).enable or false;
  tools = [ "rustfmt" ];
}
