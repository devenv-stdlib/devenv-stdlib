# Mock language-scoped options + CI matrix flag.
{ lib, ... }:
{
  path = [
    "python"
    "supported"
  ];
  description = "Mock supported.python options and ciMatrix flag.";
  module = _: {
    options.supported.python = lib.mkOption {
      type = lib.types.submodule {
        options.min = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Mock min Python version for matrix tests.";
        };
      };
      default = { };
    };
  };
  project.stdlib.lang.python.ciMatrix = true;
}
