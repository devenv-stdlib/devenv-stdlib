# Packaging: flake outputs stdlib and lib are one devenv-stdlib attrset.
{ lib, ... }:
let
  root = ../..;
  stdlib = import (root + "/stdlib") { inherit lib; };
  versionInfo = import (root + "/stdlib/version.nix");
  flake = builtins.getFlake (toString root);
  required = [
    "apiVersion"
    "den"
    "devenv"
    "mkTool"
    "version"
  ];
in
{
  testStdlibVersion = {
    expr = stdlib.version;
    expected = versionInfo.version;
  };

  testStdlibApiVersion = {
    expr = stdlib.apiVersion;
    expected = versionInfo.apiVersion;
  };

  testStdlibPublishesLoaders = {
    expr = map (name: builtins.hasAttr name stdlib) required;
    expected = [
      true
      true
      true
      true
      true
    ];
  };

  testFlakeStdlibVersion = {
    expr = flake.stdlib.version;
    expected = stdlib.version;
  };

  testFlakeLibMatchesStdlibNames = {
    expr = builtins.attrNames flake.lib;
    expected = builtins.attrNames flake.stdlib;
  };

  testFlakeLibVersion = {
    expr = flake.lib.version;
    expected = flake.stdlib.version;
  };
}
