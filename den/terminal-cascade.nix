# Pure cascade metadata for Phase 2 terminal aspects.
# terminal → exactly one of alacritty-quake | warp-quake (provider XOR).
{
  # Default include (alacritty). Warp path uses includes = [ "warp-quake" ].
  terminal = {
    includes = [ "alacritty-quake" ];
    # Mutual exclusion: developer/hub must include exactly one of these.
    xorProviders = [
      "alacritty-quake"
      "warp-quake"
    ];
  };
  alacritty-quake.includes = [ ];
  warp-quake.includes = [ ];

  # Map terminal.provider enum → aspect name (policy/guard helper for tests).
  providerAspect = {
    alacritty = "alacritty-quake";
    warp = "warp-quake";
  };
}
