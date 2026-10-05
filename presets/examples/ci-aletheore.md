# Example: Aletheore CI review + local CLI + Cursor MCP

Not loaded by `modules/devenv.nix`. Copy into consumer config if you want
explicit knobs; the template already applies `ci.github_actions.aletheore` by
default (writes `.github/workflows/aletheore.yml`, enables `tools.aletheore` /
catalog `pipx:aletheore` for local `aletheore scan`) and dogfoods the Cursor
MCP via `cursor.llmContext.aletheore.enable = true` on the `cursor-llm` aspect.

Product site / paid Aletheore AIR plans: <https://www.aletheore.com>

```nix
# GHA Action + local CLI — opt out
presets.ci.github_actions.aletheore.enable = false;
# then remove .github/workflows/aletheore.yml (also drops tools.aletheore)

# GHA Action — tune
presets.ci.github_actions.aletheore = {
  action = "Aletheore/Aletheore@24f816e9297f87853b09fe514081863dc6604d30";
  actionComment = "v0.9.22";
  failOnNewSecrets = true;
  failOnNewVulnerabilities = false;
  failOnNewLayerViolations = false;
  postPrComment = true;
};

# Cursor MCP (home-switch / cursor-llm) — opt-in catalog; dogfood on here
cursor.llmContext.aletheore.enable = true;
# Opt out: cursor.llmContext.aletheore.enable = false;
```

See [CI docs](../../docs/content/ci.md) and the Marketplace Action
[Aletheore](https://github.com/marketplace/actions/aletheore).
