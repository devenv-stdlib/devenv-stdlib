# nixosTest integration suite. Host policy is the current Ubuntu LTS and the previous one.
let
  pkgs = import <nixpkgs> { };
  inherit (pkgs) lib;
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  project = import ../../modules/lib/project.nix { inherit lib; };
  evalOk = import ./eval.nix { inherit lib versions project; };
  matrixShapes = import ./matrix-shapes.nix { inherit lib; };

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
  matrixEtc = lib.listToAttrs (
    map (name: {
      name = "devenv/matrix-${name}.yml";
      value.source = pkgs.writeText "matrix-${name}.yml" matrixShapes.fixtures.${name};
    }) matrixShapes.names
  );
  # Copy repo root into the store so versions-lib → stdlib/ci relative imports resolve.
  evalNix = pkgs.writeText "eval.nix" ''
    import ${./eval.nix} {
      lib = (import <nixpkgs> { }).lib;
      versions = import (${../..} + "/modules/languages/versions-lib.nix") {
        lib = (import <nixpkgs> { }).lib;
      };
      project = import ${../../modules/lib/project.nix} {
        lib = (import <nixpkgs> { }).lib;
      };
      matrixShapes = import (${../..} + "/tests/integration/matrix-shapes.nix") {
        lib = (import <nixpkgs> { }).lib;
      };
    }
  '';
in
assert evalOk;
assert matrixShapes.ok;
pkgs.testers.runNixOSTest {
  name = "devenv4monorepo";

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
      variables.NIX_PATH = lib.mkForce "nixpkgs=${pkgs.path}";
      etc = {
        "devenv/test-empty.yml".source = emptyYaml;
        "devenv/test-python.yml".source = pythonYaml;
        "devenv/eval.nix".source = evalNix;
        "devenv/actionlint.yaml".source = ../../.github/actionlint.yaml;
      }
      // matrixEtc;
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
    machine.succeed("grep -q ubuntu-24.04 /etc/devenv/test-empty.yml")
    machine.succeed("grep -q ubuntu-26.04 /etc/devenv/test-empty.yml")
    machine.fail("grep -q ubuntu-22.04 /etc/devenv/test-empty.yml")
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
    machine.succeed("actionlint -config-file /etc/devenv/actionlint.yaml /etc/devenv/test-empty.yml")
    machine.succeed("actionlint -config-file /etc/devenv/actionlint.yaml /etc/devenv/test-python.yml")
    for path in [
    ${lib.concatMapStringsSep "\n" (
      n: "        '/etc/devenv/matrix-${n}.yml',"
    ) matrixShapes.actionlintNames}
    ]:
        machine.succeed(f"actionlint -config-file /etc/devenv/actionlint.yaml {path}")
    machine.succeed("grep -F 'toolchain: \"nightly\"' /etc/devenv/matrix-filtered.yml")
    machine.succeed("grep -F '3.12\\\"beta' /etc/devenv/matrix-quoted-scalar.yml")
    machine.succeed("grep -F 'continue-on-error: ''${{ matrix.optional }}' /etc/devenv/matrix-mixed-optional.yml")
    machine.succeed("grep -F 'max-parallel: 2' /etc/devenv/matrix-max-parallel.yml")
    machine.succeed("grep -F 'os: [\"true\"]' /etc/devenv/matrix-empty-true-label.yml")
    machine.succeed("grep -F 'os: [\"self-hosted\", \"linux\", \"x64\", \"gpu\"]' /etc/devenv/matrix-multi-label.yml")
    machine.succeed("grep -F 'include:' /etc/devenv/matrix-empty-multi-label.yml")
  '';
}
