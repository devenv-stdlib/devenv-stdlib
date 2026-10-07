{
  versions,
  policy,
  ...
}:
{
  testPythonRowsCpythonAndPypy = {
    expr = versions.pythonRows (
      versions.emptyPython
      // {
        min = "3.12";
        max = "3.13";
        implementations = [
          "cpython"
          "pypy"
        ];
      }
    );
    expected = [
      {
        implementation = "cpython";
        version = "3.12";
        python_version = "3.12";
        policy_min = "3.12";
      }
      {
        implementation = "cpython";
        version = "3.13";
        python_version = "3.13";
        policy_min = "3.12";
      }
      {
        implementation = "pypy";
        version = "3.12";
        python_version = "pypy3.12";
        policy_min = "3.12";
      }
      {
        implementation = "pypy";
        version = "3.13";
        python_version = "pypy3.13";
        policy_min = "3.12";
      }
    ];
  };

  testRustRowsStableAndBeta = {
    expr = versions.rustRows (
      versions.emptyRust
      // {
        min = "1.80.0";
        max = "1.85.0";
        unsupported = [ "1.81.0" ];
        channels = [
          "stable"
          "beta"
        ];
      }
    );
    expected = [
      {
        channel = "stable";
        version = "1.80.0";
        policy_min = "1.80.0";
      }
      {
        channel = "stable";
        version = "1.82.0";
        policy_min = "1.80.0";
      }
      {
        channel = "stable";
        version = "1.83.0";
        policy_min = "1.80.0";
      }
      {
        channel = "stable";
        version = "1.84.0";
        policy_min = "1.80.0";
      }
      {
        channel = "stable";
        version = "1.85.0";
        policy_min = "1.80.0";
      }
      {
        channel = "beta";
        version = "latest";
        policy_min = "1.80.0";
      }
    ];
  };

  testGoRows = {
    expr = versions.goRows (
      versions.emptyGo
      // {
        min = "1.22.0";
        max = "1.24.0";
      }
    );
    expected = [
      {
        version = "1.22.0";
        policy_min = "1.22.0";
      }
      {
        version = "1.23.0";
        policy_min = "1.22.0";
      }
      {
        version = "1.24.0";
        policy_min = "1.22.0";
      }
    ];
  };

  testJavascriptRowsNodeGetsPkg = {
    expr = versions.javascriptRows (
      versions.emptyJavascript
      // {
        runtimes = [
          "nodejs"
          "bun"
        ];
        nodejs = policy {
          min = "22";
          max = "24";
        };
        bun = policy { min = "1.2.0"; };
      }
    );
    expected = [
      {
        runtime = "nodejs";
        version = "22";
        pkg = "nodejs_22";
        policy_min = "22";
      }
      {
        runtime = "nodejs";
        version = "23";
        pkg = "nodejs_23";
        policy_min = "22";
      }
      {
        runtime = "nodejs";
        version = "24";
        pkg = "nodejs_24";
        policy_min = "22";
      }
      {
        runtime = "bun";
        version = "1.2.0";
        policy_min = "1.2.0";
        pkg = "";
      }
    ];
  };

  # Nix list options concatenate. The same runtime set in devenv.nix and
  # devenv.local.nix must not emit a second copy of that runtime's rows.
  testJavascriptRowsDuplicateRuntimesCollapse = {
    expr =
      let
        base = versions.emptyJavascript // {
          nodejs = policy {
            min = "22";
            max = "22";
          };
          bun = policy { min = "1.2.0"; };
          deno = policy { min = "2.1.0"; };
        };
      in
      versions.javascriptRows (
        base
        // {
          runtimes = [
            "nodejs"
            "bun"
            "nodejs"
            "deno"
            "bun"
          ];
        }
      );
    expected = versions.javascriptRows (
      versions.emptyJavascript
      // {
        runtimes = [
          "nodejs"
          "bun"
          "deno"
        ];
        nodejs = policy {
          min = "22";
          max = "22";
        };
        bun = policy { min = "1.2.0"; };
        deno = policy { min = "2.1.0"; };
      }
    );
  };

  # Same rule as JavaScript runtimes: a repeated Python implementation
  # (cpython, pypy, …) expands once.
  testPythonRowsDuplicateImplementationsCollapse = {
    expr =
      let
        base = versions.emptyPython // {
          min = "3.12";
          max = "3.12";
        };
      in
      versions.pythonRows (
        base
        // {
          implementations = [
            "cpython"
            "pypy"
            "cpython"
            "pypy"
          ];
        }
      );
    expected = versions.pythonRows (
      versions.emptyPython
      // {
        min = "3.12";
        max = "3.12";
        implementations = [
          "cpython"
          "pypy"
        ];
      }
    );
  };
}
