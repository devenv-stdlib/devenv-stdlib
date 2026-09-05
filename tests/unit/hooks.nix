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

  testAlwaysOnHookCount = {
    expr = lib.length project.alwaysOnHookNames;
    expected = 16;
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
