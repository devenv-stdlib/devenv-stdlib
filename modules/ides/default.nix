# Compat shim. IDE project files are written by stdlib.devenv.load.
# vscode/ and cursor/ are empty shims; importing them is a no-op.
_: {
  imports = [
    ./vscode
    ./cursor
  ];
}
