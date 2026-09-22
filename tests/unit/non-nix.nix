{ lib, ... }:
let
  nonNix = import ../../modules/non-nix/lib.nix { inherit lib; };

  fakePkg =
    {
      version,
      homepage ? "",
      pname ? "tool",
    }:
    {
      inherit version pname;
      meta = { inherit homepage; };
      outPath = "/nix/store/fake-${pname}";
    };

  pkgsMissing = { };

  pkgsOldWrong = {
    rtk = fakePkg {
      version = "0.1.0";
      homepage = "https://example.com/wrong-rtk";
      pname = "rtk";
    };
  };

  pkgsPromotable = {
    rtk = fakePkg {
      version = "0.99.0";
      homepage = "https://github.com/rtk-ai/rtk";
      pname = "rtk";
    };
  };

  rtkEntry = lib.findFirst (e: e.name == "rtk") null nonNix.catalog;
  ninerouter = lib.findFirst (e: e.name == "ninerouter") null nonNix.catalog;
in
{
  testNonNixMissingAttrStaysMise = {
    expr = (nonNix.resolveOne pkgsMissing rtkEntry).via;
    expected = "cli";
  };

  testNonNixWrongHomepageStaysMise = {
    expr = (nonNix.resolveOne pkgsOldWrong rtkEntry).via;
    expected = "cli";
  };

  testNonNixVersionAndHomepagePromote = {
    expr = (nonNix.resolveOne pkgsPromotable rtkEntry).via;
    expected = "nix";
  };

  testNonNixDockerNeverInMiseToml = {
    expr =
      let
        toml = nonNix.toMiseToml [ (ninerouter // { via = "docker-image"; }) ];
      in
      lib.hasInfix "decolua" toml || lib.hasInfix "9router" toml;
    expected = false;
  };

  testNonNixUbiKeyQuotedInToml = {
    expr =
      let
        toml = nonNix.toMiseToml [
          (
            rtkEntry
            // {
              via = "cli";
              package = null;
            }
          )
        ];
      in
      lib.hasInfix ''"ubi:rtk-ai/rtk" = "'' toml;
    expected = true;
  };

  testNonNixImageRef = {
    expr = nonNix.imageRef "ninerouter";
    expected = "decolua/9router:0.5.69";
  };

  testNonNixShippedCatalogNonEmpty = {
    expr = builtins.length nonNix.shipped > 0;
    expected = true;
  };

  testNonNixBinNameFallsBackWhenBinNull = {
    expr = nonNix.binName (
      rtkEntry
      // {
        bin = null;
      }
    );
    expected = "rtk";
  };
}
