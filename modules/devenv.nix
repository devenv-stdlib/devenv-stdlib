_: {
  imports = [
    ./packages
    ./hooks/common.nix
    ./hooks/rust.nix
    ./hooks/go.nix
    ./hooks/python.nix
    ./hooks/javascript.nix
    ./debtmap/hooks.nix
    ./languages
    ./languages/versions.nix
    ./languages/cursor.nix
    ./languages/serena.nix
    ./debtmap
    ./mise
    ./update
    ./test/devenv.nix
  ];
}
