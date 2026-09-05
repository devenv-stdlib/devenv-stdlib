{ pkgs, lib }:
let
  version = "0.23.0";
  sources = {
    x86_64-linux = {
      url = "https://github.com/iepathos/debtmap/releases/download/${version}/debtmap-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "5bf89212605da09ec500fb9ecfd61b4578b80a97410ccf409df9cb5e9478635f";
    };
    x86_64-darwin = {
      url = "https://github.com/iepathos/debtmap/releases/download/${version}/debtmap-x86_64-apple-darwin.tar.gz";
      sha256 = "77a6e5c54163b7dd442778cdb9b4471cac1fe1055ac049170bc88d566bb79e25";
    };
    aarch64-darwin = {
      url = "https://github.com/iepathos/debtmap/releases/download/${version}/debtmap-aarch64-apple-darwin.tar.gz";
      sha256 = "539b7cb9dc8bddda76070cc30b9c25048e9929f478b4c4d34c4f137994f72ea4";
    };
  };
  inherit (pkgs.stdenv.hostPlatform) system;
  src =
    sources.${system} or (throw ''
      debtmap ${version} has no prebuilt binary for ${system}.
      Supported: ${lib.concatStringsSep ", " (lib.attrNames sources)}.
    '');
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "debtmap";
  inherit version;

  src = pkgs.fetchurl {
    inherit (src) url sha256;
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 debtmap $out/bin/debtmap
    runHook postInstall
  '';

  meta = {
    description = "Technical debt and risk analyzer";
    homepage = "https://github.com/iepathos/debtmap";
    license = lib.licenses.mit;
    mainProgram = "debtmap";
    platforms = lib.attrNames sources;
  };
}
