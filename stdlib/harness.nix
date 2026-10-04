# Coding-harness foundations (issue #32). Shared option shapes, config
# placement, and the project vs Home Manager split. OpenCode, Claude Code,
# and Codex product wiring is issues #33–#35, not this file.
{ lib, categories }:
let
  node = categories.resolve "harness";

  envName = value: builtins.match "[A-Z_][A-Z0-9_]*" value != null;
in
{
  category = "harness";
  inherit (node) cardinality;
  multiCardinality = node.multiCardinality or "any-of";
  knownTools = node.tools;

  # Relative to $HOME. Not a Nix store path.
  configPath = vendor: file: ".config/${vendor}/${file}";

  toolPath = name: "tools/harness/${name}.nix";
  presetPath = name: "presets/harness/${name}.nix";

  # Install kinds a later mkTool will accept. No package wiring here.
  installKinds = [
    "nix"
    "catalog"
    "self"
  ];

  # Public options a harness tool spreads into its module. `secretEnv` is a
  # list of environment variable names. Values never go into the store.
  options = name: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the ${name} coding harness.";
    };
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Package that provides the ${name} CLI.";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = ".config/${name}";
      description = "Config directory relative to HOME for ${name}. Not a store path.";
    };
    model = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Model id for ${name}. Not a credential.";
    };
    provider = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Provider id for ${name}. Credentials stay in the environment.";
    };
    secretEnv = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Env var names ${name} reads. Values are never written to the store.";
    };
  };

  # `project` is the devenv payload (no secrets). `homeManager` may name env
  # vars. A value that is not an env var name is rejected.
  payloads =
    {
      name,
      secretEnv ? [ ],
      project ? { },
      homeManager ? { },
    }:
    let
      bad = lib.filter (item: !envName item) secretEnv;
    in
    if bad != [ ] then
      throw "harness: secretEnv must be env var names"
    else
      {
        project = {
          inherit name;
        }
        // project;
        homeManager = {
          inherit name secretEnv;
          configDir = ".config/${name}";
        }
        // homeManager;
      };
}
