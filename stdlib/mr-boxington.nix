# mr-boxington (mbx) prebuilt CLI. Not in nixpkgs.
# Releases: https://github.com/jdx/mr-boxington/releases
{ pkgs }:
let
  inherit (pkgs) lib stdenv;
  version = "1.22.0";

  # Archive triple → fetchurl hash (SHA256SUMS of the .tar.gz).
  archives = {
    x86_64-linux = {
      archive = "mbx-x86_64-unknown-linux-gnu.tar.gz";
      hash = "sha256-6z6MdCd9zIMUInuizTLvAKmjYuyKkM0G72WA60ims3U=";
    };
    aarch64-linux = {
      archive = "mbx-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-t6I1A9nvyzGUHh5ot4+LM2Q6BW8i05z/dF2rbxfttlI=";
    };
    aarch64-darwin = {
      archive = "mbx-aarch64-apple-darwin.tar.gz";
      hash = "sha256-5Ui1dYSYz4IqGAtjKFl+at7Y/puzBGzZGDmRcq4w3eI=";
    };
  };

  system = stdenv.hostPlatform.system;
  selected = archives.${system} or (throw "mr-boxington: unsupported platform ${system}");
in
stdenv.mkDerivation {
  pname = "mr-boxington";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/jdx/mr-boxington/releases/download/v${version}/${selected.archive}";
    inherit (selected) hash;
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.libc
    # Prebuilt mbx links libgcc_s (not only libc).
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m755 mbx $out/bin/mbx
    runHook postInstall
  '';

  meta = {
    description = "Shared Cargo build cache (mbx) across worktrees";
    homepage = "https://github.com/jdx/mr-boxington";
    license = lib.licenses.mit;
    mainProgram = "mbx";
    platforms = builtins.attrNames archives;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
