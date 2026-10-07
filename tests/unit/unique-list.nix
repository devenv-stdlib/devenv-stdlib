{ lib, ... }:
{
  # Two modules each select compilers. listOf would concatenate; the merged
  # value keeps the first occurrence of each entry.
  testUniqueListOfKeepsFirstSeen = {
    expr =
      let
        uniqueListOf = import ../../presets/_shared/unique-list.nix { inherit lib; };
        cfg = lib.evalModules {
          modules = [
            {
              options.supported.compilers = lib.mkOption {
                type = lib.types.submodule {
                  options.runtimes = lib.mkOption {
                    type = uniqueListOf (
                      lib.types.enum [
                        "clang"
                        "gcc"
                      ]
                    );
                    default = [ ];
                  };
                };
                default = { };
              };
            }
            {
              supported.compilers.runtimes = [ "clang" ];
            }
            {
              supported.compilers.runtimes = [
                "gcc"
                "clang"
              ];
            }
          ];
        };
      in
      cfg.config.supported.compilers.runtimes;
    expected = [
      "clang"
      "gcc"
    ];
  };
}
