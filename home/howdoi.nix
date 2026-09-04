{ pkgs, ... }:
let
  # nixpkgs dropped howdoi (unmaintained; broken on Python 3.14).
  # Last upstream release on python313, same recipe as nixpkgs 25.11.
  howdoi = pkgs.python313Packages.buildPythonApplication rec {
    pname = "howdoi";
    version = "2.0.20";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "gleitz";
      repo = "howdoi";
      tag = "v${version}";
      hash = "sha256-u0k+h7Sp2t/JUnfPqRzDpEA+vNXB7CpyZ/SRvk+B9t0=";
    };

    build-system = [ pkgs.python313Packages.setuptools ];

    dependencies = with pkgs.python313Packages; [
      appdirs
      cachelib
      colorama
      cssselect
      keep
      lxml
      pygments
      pyquery
      requests
      rich
    ];

    doCheck = false;
    pythonImportsCheck = [ "howdoi" ];

    meta = {
      description = "Instant coding answers via the command line";
      homepage = "https://github.com/gleitz/howdoi";
      license = pkgs.lib.licenses.mit;
      mainProgram = "howdoi";
    };
  };
in
{
  home.packages = [ howdoi ];
}
