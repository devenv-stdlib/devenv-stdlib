# CodeRabbit CLI (official zip). Not in nixpkgs — tool owns the release pin;
# stdlib/binary.nix builds the store package (install.kind = binary).
args@{
  pkgs,
  lib,
  config,
  ...
}:
if false then
  { inherit pkgs config; }
else
  let
    tool = import ../../stdlib/tool.nix { inherit lib; };
    binary = import ../../stdlib/binary.nix { inherit lib; };
    version = "0.8.2";
  in
  tool.binaryLeaf args {
    name = "coderabbit-cli";
    category = "ide";
    defaultEnable = true;
    # CLI ships `coderabbit update`; pin bumps are manual here.
    package = binary.fromZipRelease {
      pname = "coderabbit-cli";
      inherit version;
      platformOf = binary.githubStylePlatform;
      urlFor = platform: "https://cli.coderabbit.ai/releases/${version}/coderabbit-${platform}.zip";
      hashes = {
        linux-x64 = "sha256-3yS+3+NcvdIAnKJPm44wHH/Hl7riSLZfGf/xkNuprgk=";
        linux-arm64 = "sha256-OPg0QLF6f/1xwQmOHzpAManZ/D9B8Lu440xU0UV8xbw=";
        darwin-x64 = "sha256-T+qVrLd76HWzuE4GbZD/XGllYufoP6PsumcfVsVcgXQ=";
        darwin-arm64 = "sha256-F/hH4K7Thz/GRBNtQod1I6g3eOrXRajBVRl5s2UyxBg=";
      };
      # Nix systems for meta.platforms (not the artifact keys above).
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      bin = "coderabbit";
      binLinks = [ "cr" ];
      stripRoot = false;
      # Bun embeds the app next to ELF headers; strip / autoPatchelf break argv.
      dontStrip = true;
      dontPatchELF = true;
      postFixup =
        pkgs':
        let
          inherit (pkgs') lib stdenv;
        in
        lib.optionalString stdenv.hostPlatform.isLinux ''
          patchelf \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
            --set-rpath "${lib.makeLibraryPath [ stdenv.cc.libc ]}" \
            $out/bin/coderabbit
        '';
      meta = {
        description = "CodeRabbit CLI for local code review";
        homepage = "https://www.coderabbit.ai/";
        license = lib.licenses.unfreeRedistributable;
      };
    };
  }
