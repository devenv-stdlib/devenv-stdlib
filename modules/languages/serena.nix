{
  lib,
  config,
  ...
}:
let
  project = import ../lib/project.nix { inherit lib; };
in
{
  # Regenerated on devenv:files from languages.*. Do not edit by hand.
  # Override in .serena/project.local.yml (gitignored).
  files.".serena/project.yml".yaml = {
    project_name = config.name;
    language_servers = project.serenaLanguageServers (config.languages or { });
    encoding = "utf-8";
    activation_command = null;
    activation_command_timeout = 180.0;
    line_ending = null;
    language_backend = null;
    ignore_all_files_in_gitignore = true;
    ls_specific_settings = { };
    ls_workspace_folders = [ "." ];
    ls_additional_workspace_folders = [ ];
    ignored_paths = [ ];
    read_only = false;
    excluded_tools = [ ];
    included_optional_tools = [ ];
    fixed_tools = [ ];
    default_modes = null;
    added_modes = null;
    initial_prompt = "";
    symbol_info_budget = null;
    read_only_memory_patterns = [ ];
    ignored_memory_patterns = [ ];
  };
}
