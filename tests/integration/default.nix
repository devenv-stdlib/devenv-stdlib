# nixosTest integration suite. Run on Ubuntu 22.04 (the MVP host OS).
let
  pkgs = import <nixpkgs> { };
  inherit (pkgs) lib;
  versions = import ../../modules/language-versions-lib.nix { inherit lib; };
  project = import ../../modules/project-lib.nix { inherit lib; };
  evalOk = import ./eval.nix { inherit lib versions project; };

  emptyYaml = pkgs.writeText "test-empty.yml" (versions.workflowText { });
  pythonYaml = pkgs.writeText "test-python.yml" (
    versions.workflowText {
      pythonOn = true;
      python = versions.emptyPython // {
        min = "3.12";
        max = "3.13";
      };
    }
  );
  evalNix = pkgs.writeText "eval.nix" ''
    import ${./eval.nix} {
      lib = (import <nixpkgs> { }).lib;
      versions = import ${../../modules/language-versions-lib.nix} {
        lib = (import <nixpkgs> { }).lib;
      };
      project = import ${../../modules/project-lib.nix} {
        lib = (import <nixpkgs> { }).lib;
      };
    }
  '';
in
assert evalOk;
pkgs.testers.runNixOSTest {
  name = "devenv";

  nodes.machine = {
    virtualisation.memorySize = 1024;
    virtualisation.diskSize = 4096;
    environment = {
      systemPackages = [
        pkgs.git
        pkgs.jq
        pkgs.python3
        pkgs.nix
        pkgs.actionlint
      ];
      variables.NIX_PATH = "nixpkgs=${pkgs.path}";
      etc = {
        "devenv/test-empty.yml".source = emptyYaml;
        "devenv/test-python.yml".source = pythonYaml;
        "devenv/eval.nix".source = evalNix;
      };
    };
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("git --version")
    machine.succeed("jq --version")
    machine.succeed("test -f /etc/devenv/test-empty.yml")
    machine.succeed("grep -q workflow_call /etc/devenv/test-empty.yml")
    machine.succeed("grep -q ubuntu-22.04 /etc/devenv/test-empty.yml")
    machine.succeed("grep -q no-language-matrix /etc/devenv/test-empty.yml")
    machine.fail("grep -q ubuntu-latest /etc/devenv/test-empty.yml")
    machine.fail("grep -q branches: /etc/devenv/test-empty.yml")
    machine.succeed("grep -q python: /etc/devenv/test-python.yml")
    machine.succeed("grep -q 3.12 /etc/devenv/test-python.yml")
    machine.succeed("grep -q workflow_call /etc/devenv/test-python.yml")
    machine.succeed(
        "python3 -c \"import pathlib; t=pathlib.Path('/etc/devenv/test-empty.yml').read_text(); assert 'name: Test' in t and 'workflow_call' in t\""
    )
    machine.succeed("nix-instantiate --eval --strict /etc/devenv/eval.nix")
    machine.succeed("actionlint /etc/devenv/test-empty.yml")
    machine.succeed("actionlint /etc/devenv/test-python.yml")
  '';
}
