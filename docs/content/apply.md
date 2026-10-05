# Consume the package

This repository publishes **devenv-stdlib** as a Nix flake. Consumers pin it; they do not copy this tree with Copier.

```nix
# flake.nix (see consumer-flake.nix.example)
inputs.devenv-stdlib.url = "github:thedrow/devenv4monorepo/<tag-or-sha>";
# follows (nixpkgs, den, …) reuse the pin's locked inputs — not a binary cache
# then: inputs.devenv-stdlib.stdlib / .lib
# packaging: import "${inputs.devenv-stdlib}/packaging/den-outputs.nix" { …; root = ./.; }
# presets:   "${inputs.devenv-stdlib}/presets" plus local ./presets
```

`<tag-or-sha>` should be a Git tag from semantic-release once tags exist, or a commit SHA. Lock the pin in the consumer’s `flake.lock`.

`outputs.stdlib` and `outputs.lib` are one attrset (`mkTool`, `den.load`, `devenv.load`, `version`, `apiVersion`). `mkPreset` lives at `stdlib/preset.nix` on the same pin. See [Standard library](#stdlib).

## Minimal consumer layout

| Piece | Where it comes from |
| --- | --- |
| Framework API | `inputs.devenv-stdlib.stdlib` |
| Packaging / Den flake body | `${inputs.devenv-stdlib}/packaging/den-outputs.nix` |
| Framework modules / home / tools / cache presets | Resolved from the pin inside `den-outputs.nix` (`frameworkRoot`) — do not copy them |
| Framework presets (composition) | `${inputs.devenv-stdlib}/presets` via `stdlib.*.load` |
| Your composition | Local `presets/` (e.g. attrpath includes like `presets/omer.nix`) and optional local `tools/` |
| Language / host options | Local `devenv.local.nix` / `home.local.nix` (start from the `.example` files in this repo) |

`root = ./.` is only the consumer overlay. Evaluating `homeConfigurations.developer` does **not** require a copied `modules/` or `presets/cache/` tree.

Enable languages and version bounds in **your** `devenv.local.nix` — there is no questionnaire. Copy patterns from `devenv.local.nix.example` and `home.local.nix.example`.

Optional Brave / Firecrawl keys stay in SecretSpec / gitignored `.env` (see `secretspec.toml`). This dogfood checkout defaults to the dotenv provider.

## Updates

| What you type | Who owns it | What it does |
| --- | --- | --- |
| `nix flake update devenv-stdlib` (or edit the URL + `flake.lock`) | Nix | Moves the framework pin (tools, presets, packaging) |
| `devenv update` | devenv CLI | Refreshes **other** flake inputs in `devenv.lock` |
| `update` (or `devenv run update`) | our devenv **script** | In a consumer tree without `includes/update/`: `devenv update`, then `catalog.local.toml`, then `update.local.sh`. In this publisher checkout: refresh shipped non-Nix pins only |

Bump the `devenv-stdlib` input when you want newer Serena/Headroom/MCP/debtmap pins or framework presets. Do not vendor those pins from this repo into your tree and edit them by hand.

After a pin or lock change, re-enter `devenv shell` (or `direnv reload`). If Home Manager modules on the pin changed, `home-switch`.

## Copier CLI

`copier` remains an installable tool (Home Manager + devenv packages) for a future projects feature. It is **not** how you consume devenv-stdlib today.
