{
  lib,
  versions,
  policy,
  ...
}:
let
  cataloged = import ../../modules/languages/versions-lib.nix {
    inherit lib;
    catalog = {
      python = {
        latest = "3.14.7";
        releases = [
          {
            cycle = "3.14";
            latest = "3.14.7";
            eol = false;
          }
          {
            cycle = "3.13";
            latest = "3.13.15";
            eol = false;
          }
          {
            cycle = "3.12";
            latest = "3.12.14";
            eol = false;
          }
          {
            cycle = "3.9";
            latest = "3.9.25";
            eol = true;
          }
        ];
      };
      nodejs = {
        latest = "26.8.1";
        releases = [
          {
            cycle = "26";
            latest = "26.8.1";
            eol = false;
          }
          {
            cycle = "24";
            latest = "24.20.0";
            eol = false;
          }
          {
            cycle = "23";
            latest = "23.11.1";
            eol = true;
          }
          {
            cycle = "22";
            latest = "22.23.2";
            eol = false;
          }
        ];
      };
    };
  };
in
{
  testResolvedVersionsNullMin = {
    expr = versions.resolvedVersions (policy {
      min = null;
    });
    expected = [ ];
  };

  testResolvedVersionsMinOnly = {
    expr = versions.resolvedVersions (policy {
      min = "3.12";
    });
    expected = [ "3.12" ];
  };

  testResolvedVersionsMinEqualsMax = {
    expr = versions.resolvedVersions (policy {
      min = "1.22.0";
      max = "1.22.0";
    });
    expected = [ "1.22.0" ];
  };

  testResolvedVersionsMinAndMax = {
    expr = versions.resolvedVersions (policy {
      min = "3.12";
      max = "3.13";
    });
    expected = [
      "3.12"
      "3.13"
    ];
  };

  testResolvedVersionsFillsRustMinors = {
    expr = versions.resolvedVersions (policy {
      min = "1.80.0";
      max = "1.85.0";
      unsupported = [ "1.81.0" ];
    });
    expected = [
      "1.80.0"
      "1.82.0"
      "1.83.0"
      "1.84.0"
      "1.85.0"
    ];
  };

  testResolvedVersionsFillsGoMinors = {
    expr = versions.resolvedVersions (policy {
      min = "1.22.0";
      max = "1.24.0";
    });
    expected = [
      "1.22.0"
      "1.23.0"
      "1.24.0"
    ];
  };

  testResolvedVersionsFillsNodeMajors = {
    expr = versions.resolvedVersions (policy {
      min = "22";
      max = "24";
    });
    expected = [
      "22"
      "23"
      "24"
    ];
  };

  testResolvedVersionsFillsPythonMinors = {
    expr = versions.resolvedVersions (policy {
      min = "3.11";
      max = "3.13";
    });
    expected = [
      "3.11"
      "3.12"
      "3.13"
    ];
  };

  testResolvedVersionsExplicitList = {
    expr = versions.resolvedVersions (policy {
      min = "3.10";
      max = "3.13";
      versions = [
        "3.10"
        "3.11"
        "3.12"
      ];
    });
    expected = [
      "3.10"
      "3.11"
      "3.12"
    ];
  };

  testResolvedVersionsDropsUnsupported = {
    expr = versions.resolvedVersions (policy {
      min = "1.80.0";
      max = "1.81.0";
      unsupported = [ "1.81.0" ];
    });
    expected = [ "1.80.0" ];
  };

  testResolvedVersionsExplicitDropsUnsupported = {
    expr = versions.resolvedVersions (policy {
      min = "1.80.0";
      versions = [
        "1.80.0"
        "1.81.0"
        "1.82.0"
      ];
      unsupported = [ "1.81.0" ];
    });
    expected = [
      "1.80.0"
      "1.82.0"
    ];
  };

  testInRangeAtMin = {
    expr = versions.inRange (policy {
      min = "3.12";
      max = "3.13";
    }) "3.12";
    expected = true;
  };

  testInRangeAtMax = {
    expr = versions.inRange (policy {
      min = "3.12";
      max = "3.13";
    }) "3.13";
    expected = true;
  };

  testInRangeLatestPatchAtMaxCycle = {
    expr = versions.inRange (policy {
      min = "3.12";
      max = "3.14";
    }) "3.14.7";
    expected = true;
  };

  testInRangeBelowMin = {
    expr = versions.inRange (policy { min = "3.12"; }) "3.11";
    expected = false;
  };

  testInRangeAboveMax = {
    expr = versions.inRange (policy {
      min = "3.12";
      max = "3.13";
    }) "3.14";
    expected = false;
  };

  testInRangeUnsupported = {
    expr = versions.inRange (policy {
      min = "1.80.0";
      max = "1.85.0";
      unsupported = [ "1.81.0" ];
    }) "1.81.0";
    expected = false;
  };

  testInRangeNoMax = {
    expr = versions.inRange (policy { min = "1.22.0"; }) "1.24.0";
    expected = true;
  };

  testNodePackageMajor = {
    expr = versions.nodePackage "22.11.0";
    expected = "nodejs_22";
  };

  testNodePackageShort = {
    expr = versions.nodePackage "20";
    expected = "nodejs_20";
  };

  testRustfmtEditionArgs = {
    expr = [
      (versions.rustfmtEditionArgs null)
      (versions.rustfmtEditionArgs "2021")
    ];
    expected = [
      [ ]
      [
        "--edition"
        "2021"
      ]
    ];
  };

  testHasPatch = {
    expr = [
      (versions.hasPatch "1.80.0")
      (versions.hasPatch "3.12")
      (versions.hasPatch "22")
    ];
    expected = [
      true
      false
      false
    ];
  };

  testCatalogLatestPatchOmitsEol = {
    expr = cataloged.resolvedVersionsFor "python" (policy {
      min = "3.9";
      max = "3.14";
    });
    expected = [
      "3.12.14"
      "3.13.15"
      "3.14.7"
    ];
  };

  testCatalogLatestPatchDropsUnsupportedCycle = {
    expr = cataloged.resolvedVersionsFor "python" (policy {
      min = "3.12";
      max = "3.14";
      unsupported = [ "3.13" ];
    });
    expected = [
      "3.12.14"
      "3.14.7"
    ];
  };

  testCatalogLatestPatchDropsUnsupportedLatest = {
    expr = cataloged.resolvedVersionsFor "python" (policy {
      min = "3.12";
      max = "3.14";
      unsupported = [ "3.13.15" ];
    });
    expected = [
      "3.12.14"
      "3.14.7"
    ];
  };

  testCatalogNodeSkipsEolMajors = {
    expr = cataloged.resolvedVersionsFor "nodejs" (policy {
      min = "22";
      max = "26";
    });
    expected = [
      "22.23.2"
      "24.20.0"
      "26.8.1"
    ];
  };

  testCatalogMinOnlyLatestPatch = {
    expr = cataloged.resolvedVersionsFor "python" (policy {
      min = "3.12";
    });
    expected = [ "3.12.14" ];
  };

  testPatchedRangeIgnoresCatalog = {
    expr = cataloged.resolvedVersionsFor "python" (policy {
      min = "1.80.0";
      max = "1.82.0";
    });
    expected = [
      "1.80.0"
      "1.81.0"
      "1.82.0"
    ];
  };
}
