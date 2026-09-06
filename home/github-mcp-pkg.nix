{ pkgs, lib }:
# Official github/github-mcp-server (local stdio). Auth is a wrapper that
# runs `gh auth token` — not stored here.
let
  version = "1.11.0";
  sources = {
    x86_64-linux = {
      url = "https://github.com/github/github-mcp-server/releases/download/v${version}/github-mcp-server_Linux_x86_64.tar.gz";
      sha256 = "1ibzd7zw8cpvfpnlri9866w73z5xivgi0179c7w47c68w1xvnwrv";
    };
    aarch64-linux = {
      url = "https://github.com/github/github-mcp-server/releases/download/v${version}/github-mcp-server_Linux_arm64.tar.gz";
      sha256 = "1jr0q3pb593f95sn0gf965sgz6cj09sx5ibiqilr8qbb9wjiaxiz";
    };
    x86_64-darwin = {
      url = "https://github.com/github/github-mcp-server/releases/download/v${version}/github-mcp-server_Darwin_x86_64.tar.gz";
      sha256 = "15cggfxjw5rsyr6xdf3dr486l9i5fpx35fp2r80npf5w2rfnpk77";
    };
    aarch64-darwin = {
      url = "https://github.com/github/github-mcp-server/releases/download/v${version}/github-mcp-server_Darwin_arm64.tar.gz";
      sha256 = "1v3qz553bwhvi8j3m3s7m6xdq9lh41bmkhijp6ghdacpnwprd3mh";
    };
  };
  inherit (pkgs.stdenv.hostPlatform) system;
  src =
    sources.${system} or (throw ''
      github-mcp-server ${version} has no prebuilt binary for ${system}.
      Supported: ${lib.concatStringsSep ", " (lib.attrNames sources)}.
    '');
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "github-mcp-server";
  inherit version;

  src = pkgs.fetchurl {
    inherit (src) url sha256;
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 github-mcp-server $out/bin/github-mcp-server
    runHook postInstall
  '';

  meta = {
    description = "Official GitHub MCP server";
    homepage = "https://github.com/github/github-mcp-server";
    license = lib.licenses.mit;
    mainProgram = "github-mcp-server";
    platforms = lib.attrNames sources;
  };
}
