{
  lib,
  project,
  ...
}:
{
  testLanguageHooksAllOff = {
    expr = project.languageHooks { };
    expected = {
      rustfmt = false;
      clippy = false;
      gofmt = false;
      golangci-lint = false;
      ruff = false;
      ruff-format = false;
      check-python = false;
      python-debug-statements = false;
      sort-requirements-txt = false;
      pyright = false;
      ty = false;
      prettier = false;
      debtmap = false;
    };
  };

  testLanguageHooksRust = {
    expr = project.languageHooks { languages.rust.enable = true; };
    expected = {
      rustfmt = true;
      clippy = true;
      gofmt = false;
      golangci-lint = false;
      ruff = false;
      ruff-format = false;
      check-python = false;
      python-debug-statements = false;
      sort-requirements-txt = false;
      pyright = false;
      ty = false;
      prettier = false;
      debtmap = true;
    };
  };

  testLanguageHooksGo = {
    expr = (project.languageHooks { languages.go.enable = true; }).gofmt;
    expected = true;
  };

  testLanguageHooksPythonDefaultsToPyright = {
    expr = project.languageHooks { languages.python.enable = true; };
    expected = {
      rustfmt = false;
      clippy = false;
      gofmt = false;
      golangci-lint = false;
      ruff = true;
      ruff-format = true;
      check-python = true;
      python-debug-statements = true;
      sort-requirements-txt = true;
      pyright = true;
      ty = false;
      prettier = false;
      debtmap = true;
    };
  };

  testLanguageHooksPythonTy = {
    expr = project.languageHooks {
      languages.python.enable = true;
      pythonTypeChecker = "ty";
    };
    expected = {
      rustfmt = false;
      clippy = false;
      gofmt = false;
      golangci-lint = false;
      ruff = true;
      ruff-format = true;
      check-python = true;
      python-debug-statements = true;
      sort-requirements-txt = true;
      pyright = false;
      ty = true;
      prettier = false;
      debtmap = true;
    };
  };

  testLanguageHooksJavascriptPrettier = {
    expr = (project.languageHooks { languages.javascript.enable = true; }).prettier;
    expected = true;
  };

  testLanguageHooksTypescriptPrettier = {
    expr = (project.languageHooks { languages.typescript.enable = true; }).prettier;
    expected = true;
  };

  testDebtmapLanguagesOff = {
    expr = project.debtmapLanguages { };
    expected = [ ];
  };

  testDebtmapLanguagesEnabled = {
    expr = [
      (project.debtmapLanguages { python.enable = true; })
      (project.debtmapLanguages { typescript.enable = true; })
      (project.debtmapLanguages {
        rust.enable = true;
        python.enable = true;
        javascript.enable = true;
        typescript.enable = true;
        go.enable = true;
      })
    ];
    expected = [
      [ "python" ]
      [ "typescript" ]
      [
        "rust"
        "python"
        "javascript"
        "typescript"
        "go"
      ]
    ];
  };

  testDebtmapFiles = {
    expr = [
      (project.debtmapFiles { })
      (project.debtmapFiles { python.enable = true; })
      (project.debtmapFiles {
        rust.enable = true;
        go.enable = true;
      })
    ];
    expected = [
      ""
      "\\.(py)$"
      "\\.(rs|go)$"
    ];
  };

  testAlwaysOnHookCount = {
    expr = {
      logical = lib.length project.alwaysOnHookNames;
      treefmt = lib.length project.alwaysOnTreefmtLinters;
      prek = lib.length project.alwaysOnPrekHooks;
      gitHooks = lib.length project.alwaysOnGitHookNames;
    };
    expected = {
      # 9 treefmt + 11 residual prek (lychee stays catalogued but off by default).
      logical = 20;
      treefmt = 9;
      prek = 11;
      # git-hooks exposes one `treefmt` entry plus the 11 residual hooks.
      gitHooks = 12;
    };
  };

  testTypescriptBundlers = {
    expr = project.typescriptBundlers;
    expected = [
      "vite"
      "turbopack"
      "rspack"
      "tsup"
      "tsdown"
    ];
  };

  testTypescriptBundlerMissing = {
    expr = [
      (project.typescriptBundlerMissing true null)
      (project.typescriptBundlerMissing true "vite")
      (project.typescriptBundlerMissing false null)
    ];
    expected = [
      true
      false
      false
    ];
  };

  testLangOnMissingIsFalse = {
    expr = project.langOn { } "python";
    expected = false;
  };
}
