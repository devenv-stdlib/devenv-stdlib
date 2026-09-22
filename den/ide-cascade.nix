# Pure cascade metadata for Phase 2 project IDE / sync aspects (W2.4).
# enterShell writers stay as scripts; these aspects document composition + quirks.
#
# Language *-ide-recs children feed recommendation / sync data into this hub
# (see language-cascade.nix); project-ides owns the devenv-side sync surfaces.
{
  project-ides = {
    includes = [
      "vscode-recs"
      "cursor-sync-extensions"
    ];
  };
  vscode-recs.includes = [ ];
  # Symlink language packs into ~/.cursor/extensions on every enterShell.
  cursor-sync-extensions.includes = [ ];
}
