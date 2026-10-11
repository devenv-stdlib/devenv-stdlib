{
  pkgs,
  # Null selects defaultDevenvExtensionSha256. The monorepo shim passes the
  # hash that includes/update/non-nix.sh refreshes in home/ides/ext-lib.nix.
  devenvExtensionSha256 ? null,
}:
let
  inherit (pkgs) lib;
  nonNix = import ./catalog.nix { inherit lib; };
  vsix = nonNix.entryByName "devenv-vscode";
  coderabbitEntry = nonNix.entryByName "coderabbit-vscode";
  vs = pkgs.vscode-extensions;
  # External fallback. includes/update/non-nix.sh replaces this string.
  defaultDevenvExtensionSha256 = "1bjmjrg13zynala76vz5vpm4ann1dic6awiv03w2l9rkby4agba7";
  vsixHash =
    if devenvExtensionSha256 == null then defaultDevenvExtensionSha256 else devenvExtensionSha256;

  # Open VSX VSIX URL for a catalog vscode-extension entry (registry = open-vsx).
  openVsxVsixUrl =
    entry:
    "https://open-vsx.org/api/${entry.publisher}/${entry.extension}/${entry.pin}/file/${entry.publisher}.${entry.extension}-${entry.pin}.vsix";

  extensionFromOpenVsx =
    entry:
    pkgs.vscode-utils.buildVscodeMarketplaceExtension {
      vsix = pkgs.fetchurl {
        url = openVsxVsixUrl entry;
        inherit (entry) sha256;
      };
      mktplcRef = {
        inherit (entry) publisher sha256;
        name = entry.extension;
        version = entry.pin;
      };
    };
in
rec {
  # version from modules/non-nix/catalog.toml; sha256 refreshed with the pin.
  devenvExtension = pkgs.vscode-utils.extensionFromVscodeMarketplace {
    inherit (vsix) publisher;
    name = vsix.extension;
    version = vsix.pin;
    sha256 = vsixHash;
  };

  naviCheatsheetLanguage = pkgs.vscode-utils.extensionFromVscodeMarketplace {
    publisher = "yanivmo";
    name = "navi-cheatsheet-language";
    version = "1.0.1";
    sha256 = "18bl6kkdbykxfvriiiws68f59dlj8aga0279qgjldrhsgdgnfwf6";
  };

  # Open VSX only (not on VS Marketplace). Installed by tools/ide/coderabbit.nix.
  coderabbit = extensionFromOpenVsx coderabbitEntry;

  common = [
    devenvExtension
    naviCheatsheetLanguage
    vs.jnoortheen.nix-ide
    vs.editorconfig.editorconfig
    vs.usernamehw.errorlens
    vs.mkhl.direnv
    vs.tamasfe.even-better-toml
    vs.redhat.vscode-yaml
    vs.streetsidesoftware.code-spell-checker
    vs.esbenp.prettier-vscode
    vs.eamodio.gitlens
    vs.pkief.material-icon-theme
    vs.christian-kohler.path-intellisense
  ];

  rust = [
    vs.rust-lang.rust-analyzer
    vs.vadimcn.vscode-lldb
    vs.fill-labs.dependi
  ];

  go = [
    vs.golang.go
  ];

  python = [
    vs.ms-python.python
    vs.ms-python.vscode-pylance
    vs.ms-python.debugpy
    vs.charliermarsh.ruff
  ];

  typescript = [
    vs.dbaeumer.vscode-eslint
    vs.bradlc.vscode-tailwindcss
    vs.yoavbls.pretty-ts-errors
    vs.formulahendry.auto-rename-tag
  ];

  allLanguage = rust ++ go ++ python ++ typescript;

  root = ext: "${ext}/share/vscode/extensions/${ext.vscodeExtUniqueId}";
  id = ext: ext.vscodeExtUniqueId;
}
