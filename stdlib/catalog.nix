# Resolve non-Nix catalog entries against pkgs: promote CLI tools to Nix when
# the attr exists, version is new enough, and homepage matches identity.
# Defaults point at the monorepo pin files. Callers can pass other paths.
{
  lib,
  catalogFile ? ../modules/non-nix/catalog.toml,
  localCatalogFile ? ../modules/non-nix/catalog.local.toml,
}:
let

  # TOML omits nulls; normalize optional fields for resolve/mise helpers.
  normalize =
    entry:
    entry
    // {
      nixAttr = entry.nixAttr or null;
      homepageContains = entry.homepageContains or null;
      mise = entry.mise or null;
      bin = entry.bin or null;
      image = entry.image or null;
      publisher = entry.publisher or null;
      extension = entry.extension or null;
      # marketplace (default) or open-vsx for vscode-extension pins.
      registry = entry.registry or "marketplace";
      sha256 = entry.sha256 or null;
      trustPolicyExcludes = entry.trustPolicyExcludes or null;
      allowBuilds = entry.allowBuilds or null;
      allowLowDownloads = entry.allowLowDownloads or null;
    };

  readTools =
    path:
    if builtins.pathExists path then
      map normalize ((builtins.fromTOML (builtins.readFile path)).tool or [ ])
    else
      [ ];

  shipped = readTools catalogFile;
  local = readTools localCatalogFile;

  # Local may add tools only; colliding names fight the shipped catalog.
  assertNamesUnique =
    entries:
    let
      names = map (e: e.name) entries;
      dupes = lib.unique (lib.filter (n: lib.count (x: x == n) names > 1) names);
    in
    if dupes == [ ] then
      entries
    else
      throw ''
        non-nix catalog: duplicate tool name(s): ${lib.concatStringsSep ", " dupes}.
        Rename or remove them from modules/non-nix/catalog.local.toml
        (do not override shipped modules/non-nix/catalog.toml entries).
      '';

  catalog = assertNamesUnique (shipped ++ local);

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

  # normalize sets missing bin to null; `e.bin or e.name` would stay null.
  binName = e: if e.bin != null then e.bin else e.name;

  # Quoted tool key when it contains ':' (ubi:/npm:/pipx: backends).
  # Optional aube options → object form (trust exclude / builds / low downloads).
  tomlToolLine =
    e:
    let
      key = e.mise;
      quoted = if lib.hasInfix ":" key then ''"${key}"'' else key;
      excludes = e.trustPolicyExcludes or null;
      excludeLit =
        if excludes == null || excludes == [ ] then
          null
        else
          "[ ${lib.concatMapStringsSep ", " (x: ''"${x}"'') excludes} ]";
      allowBuilds = e.allowBuilds or null;
      allowLowDownloads = e.allowLowDownloads or null;
      opts =
        lib.optional (excludeLit != null) "trust_policy_excludes = ${excludeLit}"
        ++ lib.optional (allowBuilds == true) "allow_builds = true"
        ++ lib.optional (allowLowDownloads == true) "allow_low_downloads = true";
    in
    if opts == [ ] then
      "${quoted} = \"${e.pin}\""
    else
      ''${quoted} = { version = "${e.pin}", ${lib.concatStringsSep ", " opts} }'';

  toMiseToml =
    entries:
    let
      tools = miseCli entries;
      body = if tools == [ ] then "" else lib.concatStringsSep "\n" (map tomlToolLine tools);
    in
    ''
      # Generated from modules/non-nix/catalog.toml (+ catalog.local.toml). Do not edit.
      # Languages stay on devenv; mise only installs catalog CLI fallbacks.

      [settings]
      # Keep core language backends off; devenv owns those toolchains.
      disable_tools = ["python", "node", "rust", "go"]
      # pipx: catalog entries install via `uv tool install` when uv is on PATH.
      pipx.uvx = true

      [tools]
      ${body}
    '';
in
{
  inherit
    catalog
    catalogFile
    localCatalogFile
    shipped
    local
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
