# Compat shim. Serena language_servers are contributed by
# presets/<lang>/serena.nix and written by stdlib.devenv.load. Do not import
# this file from the devenv barrel (that would define the project file twice).
# Global excluded_tools (e.g. search_for_pattern) come from
# ~/.serena/serena_config.yml via home-switch (home/ides/ensure-serena-config.py);
# project and global exclusions extend.
{ }
