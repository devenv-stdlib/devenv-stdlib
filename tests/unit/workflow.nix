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
        runner = contains "ubuntu-22.04" yaml;
        skip = contains "no-language-matrix:" yaml;
        latest = contains "ubuntu-latest" yaml;
      };
    expected = {
      name = true;
      call = true;
      push = false;
      runner = true;
      skip = true;
      latest = false;
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
        runner = contains "ubuntu-22.04" yaml;
        version = contains "3.12" yaml;
        policyMin = contains "supported.python.min" yaml;
        cache = contains "cache-nix-action" yaml;
      };
    expected = {
      call = true;
      python = true;
      skip = false;
      runner = true;
      version = true;
      policyMin = true;
      cache = true;
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

  testRunnerIsUbuntu2204 = {
    expr = versions.runner;
    expected = "ubuntu-22.04";
  };
}
