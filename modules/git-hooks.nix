{ pkgs, ... }:
{
  git-hooks.hooks = {
    nixfmt-rfc-style.enable = true;
    statix.enable = true;
    deadnix.enable = true;
    shellcheck.enable = true;
    commitlint = {
      enable = true;
      name = "commitlint";
      description = "Lint commit messages as Conventional Commits";
      package = pkgs.commitlint;
      entry = "${pkgs.commitlint}/bin/commitlint --edit";
      stages = [ "commit-msg" ];
    };

    typos.enable = true;
  };
}
