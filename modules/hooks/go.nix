# Compat shim. Go hook rules live in presets/lang/go/*.nix and are
# applied by stdlib.devenv.load from modules/devenv.nix. Do not import this
# file from the devenv barrel (that would apply the payload twice).
{ }
