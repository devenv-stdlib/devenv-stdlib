# Pure cascade metadata for Phase 2 language aspects.
# Copier still only flips languages.*.enable; this DAG is the readable fan-out.
#
# JS+TS share prettier / Serena "typescript" server / typescript IDE pack via
# today's javascriptOn — documented under `shared` (not duplicate leaf aspects).
{
  python.includes = [
    "python-hooks"
    "python-ide-recs"
    "python-serena"
    "python-debtmap"
  ];
  python-hooks.includes = [ ];
  python-ide-recs.includes = [ ];
  python-serena.includes = [ ];
  python-debtmap.includes = [ ];

  rust.includes = [
    "rust-hooks"
    "rust-ide-recs"
    "rust-serena"
    "rust-debtmap"
  ];
  rust-hooks.includes = [ ];
  rust-ide-recs.includes = [ ];
  rust-serena.includes = [ ];
  rust-debtmap.includes = [ ];

  go.includes = [
    "go-hooks"
    "go-ide-recs"
    "go-serena"
    "go-debtmap"
  ];
  go-hooks.includes = [ ];
  go-ide-recs.includes = [ ];
  go-serena.includes = [ ];
  go-debtmap.includes = [ ];

  javascript.includes = [
    "javascript-hooks"
    "javascript-ide-recs"
    "javascript-serena"
    "javascript-debtmap"
  ];
  javascript-hooks.includes = [ ];
  javascript-ide-recs.includes = [ ];
  javascript-serena.includes = [ ];
  javascript-debtmap.includes = [ ];

  typescript.includes = [
    "typescript-hooks"
    "typescript-ide-recs"
    "typescript-serena"
    "typescript-debtmap"
  ];
  typescript-hooks.includes = [ ];
  typescript-ide-recs.includes = [ ];
  typescript-serena.includes = [ ];
  typescript-debtmap.includes = [ ];

  # Cross-language dedupe (mirrors project.javascriptOn consumers).
  shared = {
    prettierVia = [
      "javascript"
      "typescript"
    ];
    serenaTypescriptServerVia = [
      "javascript"
      "typescript"
    ];
    ideTypescriptPackVia = [
      "javascript"
      "typescript"
    ];
  };

  # Language hubs migrated in Phase 2 (order matches plan W2.2 → W2.3).
  hubs = [
    "python"
    "rust"
    "go"
    "javascript"
    "typescript"
  ];
}
