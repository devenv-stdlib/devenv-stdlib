# In-repo / non-nixpkgs binary packages for install.kind = "binary".
# Tools own version, URLs, hashes, and bin layout; this file is the shared
# fetch + install API (see mkTool binaryLeaf / install.package).
{ lib }:
let
  # archives: { <nix system> = { archive = "name.tar.gz"; hash = "sha256-…"; }; … }
  fromGithubRelease =
    {
      pname,
      version,
      owner,
      repo,
      archives,
      # Installed binary name inside the archive (and $out/bin).
      bin ? pname,
      # Extra Linux libs for autoPatchelf / manual postFixup (e.g. libgcc).
      # pkgs → list of packages. Included on Linux even when autoPatchelf is false.
      extraBuildInputs ? (_pkgs: [ ]),
      # When false, skip autoPatchelfHook (caller may patch via postFixup).
      autoPatchelf ? true,
      # pkgs → shell fragment run in postFixup (same shape as fromZipRelease).
      postFixup ? (_pkgs: ""),
      meta ? { },
    }:
    pkgs:
    let
      inherit (pkgs) stdenv;
      system = stdenv.hostPlatform.system;
      selected = archives.${system} or (throw "${pname}: unsupported platform ${system}");
      defaultMeta = {
        inherit pname;
        description = pname;
        homepage = "https://github.com/${owner}/${repo}";
        mainProgram = bin;
        platforms = builtins.attrNames archives;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      };
    in
    stdenv.mkDerivation {
      inherit pname version;

      src = pkgs.fetchurl {
        url = "https://github.com/${owner}/${repo}/releases/download/v${version}/${selected.archive}";
        inherit (selected) hash;
      };

      nativeBuildInputs = lib.optionals (autoPatchelf && stdenv.hostPlatform.isLinux) [
        pkgs.autoPatchelfHook
      ];
      # Keep caller libs on Linux even when autoPatchelf is off (manual postFixup).
      buildInputs = lib.optionals stdenv.hostPlatform.isLinux (
        [
          stdenv.cc.libc
        ]
        ++ (extraBuildInputs pkgs)
      );

      dontConfigure = true;
      dontBuild = true;
      sourceRoot = ".";

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        install -m755 ${lib.escapeShellArg bin} $out/bin/${lib.escapeShellArg bin}
        runHook postInstall
      '';

      postFixup = postFixup pkgs;

      meta = defaultMeta // meta;
    };

  # Official zip releases (one binary at zip root by default).
  # platformOf: pkgs -> platform key string (e.g. "linux-x64").
  # urlFor: platform -> url; hashes: { <platform> = "sha256-…"; }
  fromZipRelease =
    {
      pname,
      version,
      platformOf,
      urlFor,
      hashes,
      bin ? pname,
      # Extra $out/bin names → same binary (e.g. cr → coderabbit).
      binLinks ? [ ],
      stripRoot ? false,
      dontStrip ? false,
      dontPatchELF ? false,
      # pkgs: string shell for postFixup (Linux ELF fixups, etc.).
      postFixup ? (_pkgs: ""),
      meta ? { },
      platforms ? builtins.attrNames hashes,
    }:
    pkgs:
    let
      inherit (pkgs) stdenv;
      platform = platformOf pkgs;
      defaultMeta = {
        inherit pname;
        description = pname;
        mainProgram = bin;
        inherit platforms;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      };
    in
    stdenv.mkDerivation {
      inherit pname version;

      src = pkgs.fetchzip {
        url = urlFor platform;
        hash = hashes.${platform} or (throw "${pname}: missing hash for platform ${platform}");
        inherit stripRoot;
      };

      nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ pkgs.patchelf ];

      dontConfigure = true;
      dontBuild = true;
      inherit dontStrip dontPatchELF;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        install -m755 ${lib.escapeShellArg bin} $out/bin/${lib.escapeShellArg bin}
        ${lib.concatMapStrings (link: ''
          ln -s ${lib.escapeShellArg bin} $out/bin/${lib.escapeShellArg link}
        '') binLinks}
        runHook postInstall
      '';

      postFixup = postFixup pkgs;

      meta = defaultMeta // meta;
    };

  # Common github-style linux/darwin x64+arm64 zip platform key.
  githubStylePlatform =
    pkgs:
    let
      inherit (pkgs) stdenv;
    in
    if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64 then
      "linux-x64"
    else if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isAarch64 then
      "linux-arm64"
    else if stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64 then
      "darwin-x64"
    else if stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64 then
      "darwin-arm64"
    else
      throw "binary: unsupported platform ${stdenv.hostPlatform.system}";
in
{
  inherit fromGithubRelease fromZipRelease githubStylePlatform;
}
