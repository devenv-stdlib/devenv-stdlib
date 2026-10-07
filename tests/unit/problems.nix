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
        latest = "3.14.6";
        releases = [
          {
            cycle = "3.14";
            latest = "3.14.6";
            eol = false;
          }
          {
            cycle = "3.13";
            latest = "3.13.14";
            eol = true;
          }
          {
            cycle = "3.12";
            latest = "3.12.13";
            eol = false;
          }
          {
            cycle = "3.9";
            latest = "3.9.25";
            eol = true;
          }
        ];
      };
    };
  };
in
{
  testProblemsEmptyWhenLanguagesOff = {
    expr = versions.problems { };
    expected = [ ];
  };

  testProblemsPythonMissingMin = {
    expr = versions.problems { pythonOn = true; };
    expected = [ "languages.python.enable requires supported.python.min" ];
  };

  testProblemsPython2Rejected = {
    expr = versions.problems {
      pythonOn = true;
      python = versions.emptyPython // {
        min = "2.7";
      };
    };
    expected = [ "supported.python.min must be Python 3 or above (got 2.7)" ];
  };

  testProblemsPythonMaxBelow3 = {
    expr = versions.problems {
      pythonOn = true;
      python = versions.emptyPython // {
        min = "3.12";
        max = "2.7";
      };
    };
    expected = [
      "supported.python.max must be Python 3 or above (got 2.7)"
      "supported.python.max (2.7) is older than min (3.12)"
      "supported.python.min and max must differ in exactly one component (or set versions explicitly)"
      "supported.python.versions must sit between min and max and omit unsupported"
    ];
  };

  testProblemsPythonMaxOlderThanMin = {
    expr = versions.problems {
      pythonOn = true;
      python = versions.emptyPython // {
        min = "3.13";
        max = "3.12";
      };
    };
    expected = [ "supported.python.max (3.12) is older than min (3.13)" ];
  };

  testProblemsPythonEmptyImplementations = {
    expr = versions.problems {
      pythonOn = true;
      python = versions.emptyPython // {
        min = "3.12";
        implementations = [ ];
      };
    };
    expected = [ "supported.python.implementations must include cpython and/or pypy" ];
  };

  testProblemsPythonVersionsOutOfRange = {
    expr = versions.problems {
      pythonOn = true;
      python = versions.emptyPython // {
        min = "3.12";
        max = "3.13";
        versions = [ "3.11" ];
      };
    };
    expected = [ "supported.python.versions must sit between min and max and omit unsupported" ];
  };

  # A min/max that enumerates one version, then lists that version in
  # unsupported, must fail. This does not need a catalog release.
  testProblemsUnsupportedRemovesOnlyVersion = {
    expr = versions.problems {
      pythonOn = true;
      python = versions.emptyPython // {
        min = "3.12";
        max = "3.12";
        unsupported = [ "3.12" ];
      };
    };
    expected = [ "supported.python has no supported versions between min and max" ];
  };

  testProblemsPythonOk = {
    expr = versions.problems {
      pythonOn = true;
      python = versions.emptyPython // {
        min = "3.12";
        max = "3.13";
        implementations = [
          "cpython"
          "pypy"
        ];
      };
    };
    expected = [ ];
  };

  testProblemsRustMissingMin = {
    expr = versions.problems { rustOn = true; };
    expected = [ "languages.rust.enable requires supported.rust.min" ];
  };

  testProblemsRustWithoutStable = {
    expr = versions.problems {
      rustOn = true;
      rust = versions.emptyRust // {
        min = "1.80.0";
        channels = [ "nightly" ];
      };
    };
    expected = [ "supported.rust.channels must include stable" ];
  };

  testProblemsRustMaxOlderThanMin = {
    expr = versions.problems {
      rustOn = true;
      rust = versions.emptyRust // {
        min = "1.85.0";
        max = "1.80.0";
      };
    };
    expected = [ "supported.rust.max (1.80.0) is older than min (1.85.0)" ];
  };

  testProblemsRustEdition2021OlderThanMin = {
    expr = versions.problems {
      rustOn = true;
      rust = versions.emptyRust // {
        min = "1.50.0";
        edition = "2021";
      };
    };
    expected = [ "supported.rust.edition 2021 requires rustc 1.56.0 or newer (min is 1.50.0)" ];
  };

  testProblemsRustEditionOlderThanMin = {
    expr = versions.problems {
      rustOn = true;
      rust = versions.emptyRust // {
        min = "1.80.0";
        edition = "2024";
      };
    };
    expected = [ "supported.rust.edition 2024 requires rustc 1.85.0 or newer (min is 1.80.0)" ];
  };

  testProblemsRustEditionOlderThanMax = {
    expr = versions.problems {
      rustOn = true;
      rust = versions.emptyRust // {
        min = "1.80.0";
        max = "1.84.0";
        edition = "2024";
      };
    };
    expected = [
      "supported.rust.edition 2024 requires rustc 1.85.0 or newer (min is 1.80.0)"
      "supported.rust.edition 2024 requires rustc 1.85.0 or newer (max is 1.84.0)"
    ];
  };

  testProblemsRustEditionOlderThanMaxOnly = {
    expr = versions.problems {
      rustOn = true;
      rust = versions.emptyRust // {
        min = "1.90.0";
        max = "1.80.0";
        edition = "2024";
      };
    };
    expected = [
      "supported.rust.max (1.80.0) is older than min (1.90.0)"
      "supported.rust.edition 2024 requires rustc 1.85.0 or newer (max is 1.80.0)"
    ];
  };

  testProblemsRustEditionOk = {
    expr = versions.problems {
      rustOn = true;
      rust = versions.emptyRust // {
        min = "1.85.0";
        max = "1.90.0";
        edition = "2024";
      };
    };
    expected = [ ];
  };

  testProblemsRustMultiComponentRange = {
    expr = versions.problems {
      rustOn = true;
      rust = versions.emptyRust // {
        min = "1.80.0";
        max = "2.0.0";
      };
    };
    expected = [
      "supported.rust.min and max must differ in exactly one component (or set versions explicitly)"
    ];
  };

  testProblemsGoMissingMin = {
    expr = versions.problems { goOn = true; };
    expected = [ "languages.go.enable requires supported.go.min" ];
  };

  testProblemsGoMaxOlderThanMin = {
    expr = versions.problems {
      goOn = true;
      go = versions.emptyGo // {
        min = "1.24.0";
        max = "1.22.0";
      };
    };
    expected = [ "supported.go.max (1.22.0) is older than min (1.24.0)" ];
  };

  testProblemsJavascriptEmptyRuntimes = {
    expr = versions.problems { javascriptOn = true; };
    expected = [
      "languages.javascript or languages.typescript requires supported.javascript.runtimes (nodejs, bun, deno)"
    ];
  };

  testProblemsJavascriptRuntimeMissingMin = {
    expr = versions.problems {
      javascriptOn = true;
      javascript = versions.emptyJavascript // {
        runtimes = [ "nodejs" ];
      };
    };
    expected = [ "supported.javascript.nodejs.min is required when nodejs is selected" ];
  };

  testProblemsJavascriptRuntimeMaxOlder = {
    expr = versions.problems {
      javascriptOn = true;
      javascript = versions.emptyJavascript // {
        runtimes = [ "bun" ];
        bun = policy {
          min = "1.2.0";
          max = "1.1.0";
        };
      };
    };
    expected = [ "supported.javascript.bun.max (1.1.0) is older than min (1.2.0)" ];
  };

  testProblemsDenoOk = {
    expr = versions.problems {
      javascriptOn = true;
      javascript = versions.emptyJavascript // {
        runtimes = [ "deno" ];
        deno = policy { min = "2.1.0"; };
      };
    };
    expected = [ ];
  };

  testProblemsPythonMaxEol = {
    expr = cataloged.problems {
      pythonOn = true;
      python = cataloged.emptyPython // {
        min = "3.12";
        max = "3.13";
      };
    };
    expected = [ "supported.python.max (3.13) has reached end of life" ];
  };

  testProblemsPythonMinEol = {
    expr = cataloged.problems {
      pythonOn = true;
      python = cataloged.emptyPython // {
        min = "3.9";
      };
    };
    expected = [ "supported.python.min (3.9) has reached end of life" ];
  };

  testProblemsPythonUnknownCycle = {
    expr = cataloged.problems {
      pythonOn = true;
      python = cataloged.emptyPython // {
        min = "3.99";
      };
    };
    expected = [ "supported.python.min (3.99) is not in the toolchain catalog" ];
  };

  testProblemsPythonCatalogOk = {
    expr = cataloged.problems {
      pythonOn = true;
      python = cataloged.emptyPython // {
        min = "3.12";
        max = "3.14";
      };
    };
    expected = [ ];
  };
}
