# Nested category tree. Each node has its own cardinality. `tools` lists
# registered names only — this file does not define tool modules.
# Profilers are not flat: cpu and memory are separate nodes (Omer, 2026-10-03).
# `lang.*` and `services.*` mirror every devenv language/service id
# (stdlib/devenv-supported.nix).
{ lib }:
let
  supported = import ./devenv-supported.nix;

  cardinalities = [
    "exactly-one"
    "any-of"
    "zero-or-one"
    "bundle"
  ];

  n =
    cardinality: description: extra:
    let
      tools = extra.tools or [ ];
    in
    assert lib.assertMsg (lib.elem cardinality cardinalities)
      "stdlib.categories: bad cardinality ${cardinality}";
    assert lib.assertMsg (
      tools == lib.unique tools
    ) "stdlib.categories: duplicate tools under one node";
    {
      inherit cardinality description tools;
      children = extra.children or { };
    }
    // builtins.removeAttrs extra [
      "tools"
      "children"
    ];

  # Optional richer descriptions for languages that already have framework notes.
  langDescriptions = {
    go = "Go tools.";
    haskell = "Haskell tools. No framework Haskell tool presets yet.";
    javascript = "JavaScript tools.";
    nix = "Nix tools.";
    python = "Python tools.";
    rust = "Rust tools that are not linters (for example cargo-nextest).";
    typescript = "TypeScript tools that are not linters (for example pnpm).";
  };

  mkLangNode =
    lang:
    n "bundle" (langDescriptions.${lang} or "${lang} tools.") {
      categoryPolicy = lang;
      children.linters = n "bundle" "${lang} linters and formatters." { };
    };

  langChildren = lib.listToAttrs (
    map (lang: {
      name = lang;
      value = mkLangNode lang;
    }) supported.languages
  );

  mkServiceNode =
    svc:
    n "bundle" "devenv services.${svc} wiring and adjacent tool presets." {
      categoryPolicy = "services.${svc}";
    };

  serviceChildren = lib.listToAttrs (
    map (svc: {
      name = svc;
      value = mkServiceNode svc;
    }) supported.services
  );

  tree = {
    ai-gateways = n "zero-or-one" "Local model router. Both leaves are shelved." {
      shelved = [
        "9router"
        "litellm"
      ];
    };
    cache = n "bundle" "Compile caches." { };
    containers = n "bundle" "Container engine and image CLIs." { };
    data = n "bundle" "Data clients. Servers stay devenv services." { };
    debuggers =
      n "any-of" "Debuggers. Language presets attach them; they are not copied under lang/."
        { };
    docs = n "bundle" "Docs and diagram CLIs." { };
    harness =
      n "exactly-one" "One coding harness. A multi-harness preset may switch this node to any-of."
        {
          multiCardinality = "any-of";
          tools = [
            "opencode"
            "claude-code"
            "codex"
          ];
        };
    http = n "bundle" "HTTP and gRPC clients." { };
    ide = n "any-of" "Editors. More than one may be enabled." { };
    infra = n "bundle" "Infrastructure CLIs, grouped by job." {
      children = {
        cloud = n "bundle" "Cloud CLIs. Opt-in; no file trigger." { };
        iac =
          n "exactly-one" "One of terraform or opentofu. Other IaC leaves are not part of that choice."
            { };
        kubernetes = n "bundle" "Kubernetes clients. Cluster runtimes are the cluster child." {
          children.cluster = n "zero-or-one" "One local cluster runtime (kind, minikube, or k3d)." { };
        };
      };
    };
    lang =
      n "bundle" "Language toolchains. One child per devenv languages.* id. Linters nest one level down."
        {
          children = langChildren;
        };
    services =
      n "bundle" "devenv services.*. Client CLIs stay under data/; servers stay devenv modules."
        {
          children = serviceChildren;
        };
    linters =
      n "bundle" "Cross-cutting formatters and linters. Language-specific ones live under lang/."
        { };
    mcp = n "any-of" "MCP servers, nested by job." {
      children = {
        code = n "any-of" "Code and symbol MCP servers." { };
        docs = n "any-of" "Documentation MCP servers." { };
        git = n "any-of" "Git MCP servers." { };
        web = n "any-of" "Web MCP servers." { };
      };
    };
    monitor = n "bundle" "Activity monitors and timing. Not file watchers." { };
    profilers = n "bundle" "Profilers. CPU and memory are separate nodes, not one flat list." {
      children = {
        cpu = n "bundle" "CPU and sampling profilers." {
          tools = [
            "samply"
            "py-spy"
            "cargo-flamegraph"
            "pprof"
          ];
        };
        memory = n "bundle" "Memory profilers." {
          tools = [
            "valgrind"
            "cargo-valgrind"
          ];
        };
      };
    };
    release = n "bundle" "Local changelog and version CLIs." {
      children.changelog = n "zero-or-one" "One changelog generator (git-cliff or cocogitto)." { };
    };
    scanners = n "bundle" "Secret, dependency, and image scanners. Not lang/ and not linters/." { };
    secrets = n "bundle" "Decrypt and inject secrets. Not scanners." { };
    shell =
      n "bundle"
        "Interactive shells and extras. bash/zsh/elvish are tools; completion stays on this node."
        {
          tools = [
            "bash"
            "zsh"
            "elvish"
            "blesh"
          ];
          children = {
            history = n "zero-or-one" "Shell history (atuin)." { };
            nav = n "bundle" "Directory navigation (zoxide, fzf)." { };
            prompt = n "zero-or-one" "Shell prompt (starship)." { };
          };
        };
    tasks = n "bundle" "Task runners and file watchers beside devenv tasks." { };
    terminal = n "exactly-one" "One terminal provider." {
      children.mux = n "zero-or-one" "Optional terminal multiplexer." { };
    };
    tui = n "bundle" "Full-screen terminal UIs. Not the CLIs they wrap." { };
    vcs = n "bundle" "Version-control CLIs. Not TUIs and not programs.git." { };
  };

  flatten =
    prefix: kids:
    lib.concatLists (
      lib.mapAttrsToList (
        name: child:
        let
          path = if prefix == "" then name else "${prefix}.${name}";
        in
        [ path ] ++ (flatten path child.children)
      ) kids
    );

  paths = lib.sort (a: b: a < b) (flatten "" tree);

  resolve =
    dotted:
    let
      parts = lib.splitString "." dotted;
      walk =
        node: rest:
        if rest == [ ] then
          node
        else
          let
            name = lib.head rest;
          in
          if node.children ? ${name} then
            walk node.children.${name} (lib.tail rest)
          else
            throw "stdlib.categories: no node '${dotted}'";
    in
    if dotted == "" || parts == [ "" ] then
      throw "stdlib.categories: empty category path"
    else
      let
        name = lib.head parts;
      in
      if tree ? ${name} then
        walk tree.${name} (lib.tail parts)
      else
        throw "stdlib.categories: no node '${dotted}'";

  collectTools =
    prefix: kids:
    lib.concatLists (
      lib.mapAttrsToList (
        name: child:
        let
          path = if prefix == "" then name else "${prefix}.${name}";
        in
        map (tool: {
          inherit tool path;
        }) child.tools
        ++ collectTools path child.children
      ) kids
    );

  toolRefs = collectTools "" tree;
  toolNames = map (ref: ref.tool) toolRefs;
  duplicateTools = lib.unique (lib.filter (name: lib.count (x: x == name) toolNames > 1) toolNames);

  cardinalityViolation =
    node: enabled:
    let
      nEnabled = builtins.length enabled;
    in
    if node.cardinality == "exactly-one" && nEnabled != 1 then
      "exactly-one node requires one enabled tool (got ${toString nEnabled})"
    else if node.cardinality == "zero-or-one" && nEnabled > 1 then
      "zero-or-one node allows at most one enabled tool (got ${toString nEnabled})"
    else
      null;
in
assert lib.assertMsg (
  duplicateTools == [ ]
) "stdlib.categories: tool name registered twice: ${lib.concatStringsSep ", " duplicateTools}";
{
  inherit
    cardinalities
    tree
    paths
    resolve
    cardinalityViolation
    supported
    ;
}
