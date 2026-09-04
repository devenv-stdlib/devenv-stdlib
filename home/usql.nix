{ pkgs, ... }:
let
  # nixpkgs uses `most` (stable, no CGO extras). `all` adds every supported
  # driver except the `bad` group — odbc, godror, and the rest.
  usql = pkgs.usql.overrideAttrs (old: {
    tags = map (t: if t == "most" then "all" else t) (
      old.tags or [
        "most"
        "sqlite_app_armor"
        "sqlite_fts5"
        "sqlite_introspect"
        "sqlite_json1"
        "sqlite_math_functions"
        "sqlite_stat4"
        "sqlite_vtable"
        "no_adodb"
      ]
    );
  });
in
{
  home.packages = [ usql ];
}
