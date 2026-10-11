{ lib, config, ... }:
let
  cfg = config.docker.rootless;
in
{
  options.docker.rootless.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Point docker and act at the rootless Engine socket
      ($XDG_RUNTIME_DIR/docker.sock). This stack assumes rootless Docker
      (needed for local act). Set false or export
      DOCKER_HOST to use a rootful daemon.
    '';
  };

  config = lib.mkIf cfg.enable {
    home.file.".bashrc.d/20-docker-rootless.sh".text = ''
      # shellcheck disable=SC1091
      . ${./docker-rootless.sh}
      docker_rootless_env
    '';
  };
}
