{ pkgs, lib }:
# rtk-ai/rtk (not crates.io Rust Type Kit). devenv-nixpkgs has pkgs.rtk
# 0.45.0, but home-switch evaluates <nixpkgs> from NIX_PATH, not that lock.
# Pin official musl/darwin (and aarch64-linux gnu) release binaries.
let
  version = "0.48.0";
  sources = {
    x86_64-linux = {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "e4e650fa1677c0de2f6839a6040d7b17f312d32f163c402b75af70e9e5af1a91";
    };
    aarch64-linux = {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-aarch64-unknown-linux-gnu.tar.gz";
      sha256 = "5ed65486a96077bd6bba7c87fdc9d0e4a1918d19619be3c87380888389a30c7c";
    };
    x86_64-darwin = {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-x86_64-apple-darwin.tar.gz";
      sha256 = "a95f2c23e08572dcc84ddff5fbe432e41e7f94369622eb086cca49ae0b6f61e8";
    };
    aarch64-darwin = {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-aarch64-apple-darwin.tar.gz";
      sha256 = "4fa025cc93a744b6963f4e53a008e5ba3f74b6a38061f4a47c639e1c3023e0db";
    };
  };
  inherit (pkgs.stdenv.hostPlatform) system;
  src =
    sources.${system} or (throw ''
      rtk ${version} has no prebuilt binary for ${system}.
      Supported: ${lib.concatStringsSep ", " (lib.attrNames sources)}.
    '');
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "rtk";
  inherit version;

  src = pkgs.fetchurl {
    inherit (src) url sha256;
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 rtk $out/bin/rtk
    runHook postInstall
  '';

  meta = {
    description = "CLI proxy that reduces LLM token consumption on common dev commands";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.asl20;
    mainProgram = "rtk";
    platforms = lib.attrNames sources;
  };
}
