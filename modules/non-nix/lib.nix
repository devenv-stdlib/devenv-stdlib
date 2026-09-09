# Resolve non-Nix catalog entries against pkgs: promote CLI tools to Nix when
# the attr exists, version is new enough, and homepage matches identity.
{ lib }:
let
  catalogFile = ./catalog.json;
  catalog = builtins.fromJSON (builtins.readFile catalogFile);

  attrPath =
    entry:
    if entry.nixAttr == null then
      null
    else if builtins.isList entry.nixAttr then
      entry.nixAttr
    else
      [ entry.nixAttr ];

  pkgFor =
    pkgs: entry:
    let
      path = attrPath entry;
    in
    if path == null then null else lib.attrByPath path null pkgs;

  identityOk =
    pkg: entry:
    let
      needle = entry.homepageContains or null;
      home = pkg.meta.homepage or "";
      pname = pkg.pname or pkg.name or "";
    in
    needle == null || lib.hasInfix needle home || lib.hasInfix needle pname;

  # Prefer Nix when pin is met and identity matches; otherwise mise/docker/vsix.
  resolveOne =
    pkgs: entry:
    let
      pkg = pkgFor pkgs entry;
      useNix =
        entry.kind == "cli"
        && pkg != null
        && (pkg ? version)
        && lib.versionAtLeast pkg.version entry.pin
        && identityOk pkg entry;
    in
    entry
    // {
      via = if useNix then "nix" else entry.kind;
      package = if useNix then pkg else null;
    };

  resolve = pkgs: map (resolveOne pkgs) catalog;

  filterScope = scope: entries: builtins.filter (e: e.scope == scope) entries;

  nixPackages = entries: map (e: e.package) (builtins.filter (e: e.via == "nix") entries);

  miseCli = entries: builtins.filter (e: e.kind == "cli" && e.via != "nix") entries;

  dockerImages =
    entries: map (e: "${e.image}:${e.pin}") (builtins.filter (e: e.kind == "docker-image") entries);

  entryByName =
    name:
    let
      hits = builtins.filter (e: e.name == name) catalog;
    in
    if hits == [ ] then null else builtins.head hits;

  resolvedByName =
    pkgs: name:
    let
      hits = builtins.filter (e: e.name == name) (resolve pkgs);
    in
    if hits == [ ] then null else builtins.head hits;

  imageRef =
    name:
    let
      e = entryByName name;
    in
    if e == null || e.kind != "docker-image" then null else "${e.image}:${e.pin}";

  binName = e: e.bin or e.name;

  # Quoted tool key when it contains ':' (ubi:/npm:/pipx: backends).
  tomlToolLine =
    e:
    let
      key = e.mise;
      quoted = if lib.hasInfix ":" key then ''"${key}"'' else key;
    in
    "${quoted} = \"${e.pin}\"";

  toMiseToml =
    entries:
    let
      tools = miseCli entries;
      body = if tools == [ ] then "" else lib.concatStringsSep "\n" (map tomlToolLine tools);
    in
    ''
      # Generated from modules/non-nix/catalog.json. Do not edit.
      # Languages stay on devenv; mise only installs catalog CLI fallbacks.

      [settings]
      # Keep core language backends off; devenv owns those toolchains.
      disable_tools = ["python", "node", "rust", "go"]

      [tools]
      ${body}
    '';
in
{
  inherit
    catalog
    catalogFile
    resolve
    filterScope
    nixPackages
    miseCli
    dockerImages
    entryByName
    resolvedByName
    imageRef
    binName
    toMiseToml
    resolveOne
    ;
}
