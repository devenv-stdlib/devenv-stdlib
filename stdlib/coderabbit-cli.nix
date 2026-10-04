# Official CodeRabbit CLI zip (Bun standalone). Not in nixpkgs.
# Releases: https://cli.coderabbit.ai/releases/<version>/coderabbit-<platform>.zip
{ pkgs }:
let
  inherit (pkgs) lib stdenv;
  version = "0.8.2";

  platform =
    if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64 then
      "linux-x64"
    else if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isAarch64 then
      "linux-arm64"
    else if stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64 then
      "darwin-x64"
    else if stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64 then
      "darwin-arm64"
    else
      throw "coderabbit-cli: unsupported platform ${stdenv.hostPlatform.system}";

  # fetchzip stripRoot = false (zip root is the binary, not a directory).
  hashes = {
    linux-x64 = "sha256-3yS+3+NcvdIAnKJPm44wHH/Hl7riSLZfGf/xkNuprgk=";
    linux-arm64 = "sha256-OPg0QLF6f/1xwQmOHzpAManZ/D9B8Lu440xU0UV8xbw=";
    darwin-x64 = "sha256-T+qVrLd76HWzuE4GbZD/XGllYufoP6PsumcfVsVcgXQ=";
    darwin-arm64 = "sha256-F/hH4K7Thz/GRBNtQod1I6g3eOrXRajBVRl5s2UyxBg=";
  };
in
stdenv.mkDerivation {
  pname = "coderabbit-cli";
  inherit version;

  src = pkgs.fetchzip {
    url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-${platform}.zip";
    hash = hashes.${platform};
    stripRoot = false;
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ pkgs.patchelf ];

  dontConfigure = true;
  dontBuild = true;
  # Bun embeds the app next to ELF headers; strip / autoPatchelf break argv dispatch.
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m755 coderabbit $out/bin/coderabbit
    ln -s coderabbit $out/bin/cr
    runHook postInstall
  '';

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    patchelf \
      --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath "${lib.makeLibraryPath [ stdenv.cc.libc ]}" \
      $out/bin/coderabbit
  '';

  meta = {
    description = "CodeRabbit CLI for local code review";
    homepage = "https://www.coderabbit.ai/";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "coderabbit";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
