{
  versions,
  policy,
  contains,
  ...
}:
{
  testWorkflowNoLanguagesIsReusable = {
    expr =
      let
        yaml = versions.workflowText { };
      in
      {
        name = contains "name: Test" yaml;
        call = contains "workflow_call:" yaml;
        push = contains "branches:" yaml;
        runner24 = contains "ubuntu-24.04" yaml;
        runner26 = contains "ubuntu-26.04" yaml;
        skip = contains "no-language-matrix:" yaml;
        skipQuoted = contains ''run: echo "No languages enabled; skipping per-version devenv test."'' yaml;
        latest = contains "ubuntu-latest" yaml;
        jammy = contains "ubuntu-22.04" yaml;
      };
    expected = {
      name = true;
      call = true;
      push = false;
      runner24 = true;
      runner26 = true;
      skip = true;
      skipQuoted = true;
      latest = false;
      jammy = false;
    };
  };

  testWorkflowPythonJob = {
    expr =
      let
        yaml = versions.workflowText {
          pythonOn = true;
          python = versions.emptyPython // {
            min = "3.12";
          };
        };
      in
      {
        call = contains "workflow_call:" yaml;
        python = contains "python:" yaml;
        skip = contains "no-language-matrix:" yaml;
        runner24 = contains "ubuntu-24.04" yaml;
        runner26 = contains "ubuntu-26.04" yaml;
        matrixOs = contains "matrix.os" yaml;
        version = contains "3.12" yaml;
        policyMin = contains "supported.python.min" yaml;
        cache = contains "cache-nix-action/restore" yaml;
        cacheSave = contains "cache-nix-action/save" yaml;
        # Own-workspace chown must tolerate vanished /nix store locks under act.
        actOwnFallback = contains ''if ! sudo chown -R "$(id -u):$(id -g)" /nix; then'' yaml;
      };
    expected = {
      call = true;
      python = true;
      skip = false;
      runner24 = true;
      runner26 = true;
      matrixOs = true;
      version = true;
      policyMin = true;
      cache = true;
      cacheSave = true;
      actOwnFallback = true;
    };
  };

  testWorkflowRustGoJavascriptJobs = {
    expr =
      let
        yaml = versions.workflowText {
          rustOn = true;
          goOn = true;
          javascriptOn = true;
          rust = versions.emptyRust // {
            min = "1.80.0";
          };
          go = versions.emptyGo // {
            min = "1.22.0";
          };
          javascript = versions.emptyJavascript // {
            runtimes = [ "deno" ];
            deno = policy { min = "2.1.0"; };
          };
        };
      in
      {
        rust = contains "rust:" yaml;
        go = contains "go:" yaml;
        javascript = contains "javascript:" yaml;
        deno = contains "languages.deno.enable" yaml;
      };
    expected = {
      rust = true;
      go = true;
      javascript = true;
      deno = true;
    };
  };

  testUbuntuLts = {
    expr = versions.ubuntuLts;
    expected = {
      previous = "24.04";
      current = "26.04";
    };
  };

  testUbuntuLtsRunners = {
    expr = versions.ubuntuRunners;
    expected = [
      "ubuntu-24.04"
      "ubuntu-26.04"
    ];
  };

  testCrossOsExpandsRunners = {
    expr = versions.crossOs [ { version = "3.12"; } ];
    expected = [
      {
        os = "ubuntu-24.04";
        version = "3.12";
      }
      {
        os = "ubuntu-26.04";
        version = "3.12";
      }
    ];
  };
}
