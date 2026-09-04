{ pkgs }:
let
  vs = pkgs.vscode-extensions;
in
rec {
  devenvExtension = pkgs.vscode-utils.extensionFromVscodeMarketplace {
    name = "devenv";
    publisher = "datakurre";
    version = "0.7.0";
    sha256 = "1bjmjrg13zynala76vz5vpm4ann1dic6awiv03w2l9rkby4agba7";
  };

  common = [
    devenvExtension
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
