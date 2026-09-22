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
    navi = fakePkg {
      version = "0.1.0";
      homepage = "https://example.com/wrong-navi";
      pname = "navi";
    };
  };

  pkgsPromotable = {
    navi = fakePkg {
      version = "9.99.0";
      homepage = "https://github.com/denisidoro/navi";
      pname = "navi";
    };
  };

  naviEntry = lib.findFirst (e: e.name == "navi") null nonNix.catalog;
  # Synthetic docker-image entry — catalog no longer ships docker-mcp.
  sampleDockerImage = {
    name = "sample-docker-image";
    kind = "docker-image";
    scope = "user";
    pin = "1.0.0";
    image = "example/sample";
    mise = null;
    bin = null;
    nixAttr = [ ];
    homepageContains = null;
  };
in
{
  testNonNixMissingAttrStaysMise = {
    expr = (nonNix.resolveOne pkgsMissing naviEntry).via;
    expected = "cli";
  };

  testNonNixWrongHomepageStaysMise = {
    expr = (nonNix.resolveOne pkgsOldWrong naviEntry).via;
    expected = "cli";
  };

  testNonNixVersionAndHomepagePromote = {
    expr = (nonNix.resolveOne pkgsPromotable naviEntry).via;
    expected = "nix";
  };

  testNonNixDockerNeverInMiseToml = {
    expr =
      let
        toml = nonNix.toMiseToml [ (sampleDockerImage // { via = "docker-image"; }) ];
      in
      lib.hasInfix "example/sample" toml || lib.hasInfix "sample-docker-image" toml;
    expected = false;
  };

  testNonNixUbiKeyQuotedInToml = {
    expr =
      let
        toml = nonNix.toMiseToml [
          (
            naviEntry
            // {
              via = "cli";
              package = null;
            }
          )
        ];
      in
      lib.hasInfix ''"ubi:denisidoro/navi" = "'' toml;
    expected = true;
  };

  testNonNixMiseTomlEnablesPipxUvx = {
    expr = lib.hasInfix "pipx.uvx = true" (nonNix.toMiseToml [ ]);
    expected = true;
  };

  testNonNixUvCatalogEntry = {
    expr =
      let
        uv = lib.findFirst (e: e.name == "uv") null nonNix.catalog;
      in
      uv != null && uv.mise == "ubi:astral-sh/uv";
    expected = true;
  };

  testNonNixTrustPolicyExcludesInToml = {
    expr =
      let
        e = lib.findFirst (x: x.name == "git-conflict-mcp") null nonNix.catalog;
        toml = nonNix.toMiseToml [
          (
            e
            // {
              via = "cli";
              package = null;
            }
          )
        ];
      in
      lib.hasInfix "trust_policy_excludes" toml
      && lib.hasInfix "git-conflict-mcp@1.12.5" toml
      && lib.hasInfix "allow_builds = true" toml
      && lib.hasInfix "allow_low_downloads = true" toml;
    expected = true;
  };

  testNonNixImageRefMissingIsNull = {
    expr = nonNix.imageRef "docker-mcp";
    expected = null;
  };

  testNonNixDockerImagesList = {
    expr = nonNix.dockerImages [ sampleDockerImage ];
    expected = [ "example/sample:1.0.0" ];
  };

  testNonNixShippedCatalogNonEmpty = {
    expr = builtins.length nonNix.shipped > 0;
    expected = true;
  };

  testNonNixBinNameFallsBackWhenBinNull = {
    expr = nonNix.binName (
      naviEntry
      // {
        bin = null;
      }
    );
    expected = "navi";
  };
}
