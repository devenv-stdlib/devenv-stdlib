# Example: Aletheore CI review

Not loaded by `modules/devenv.nix`. Copy into consumer config if you want
explicit knobs; the template already applies `ci.github_actions.aletheore` by
default (writes `.github/workflows/aletheore.yml`).

Product site / paid Aletheore AIR plans: <https://www.aletheore.com>

```nix
# Opt out
presets.ci.github_actions.aletheore.enable = false;
# then remove .github/workflows/aletheore.yml

# Tune
presets.ci.github_actions.aletheore = {
  action = "Aletheore/Aletheore@v0.9.22";
  failOnNewSecrets = true;
  failOnNewVulnerabilities = false;
  failOnNewLayerViolations = false;
  postPrComment = true;
};
```

See [CI docs](../../docs/content/ci.md) and the Marketplace Action
[Aletheore](https://github.com/marketplace/actions/aletheore).
