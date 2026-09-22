# Den composition model (full-rewrite path)

**Status:** accepted (Phase 0)  
**Related:** [cascade inventory](../den/cascade-inventory.md) · [denful org inventory](https://github.com/denful) (Project store) · full rewrite plan Phase 0

We are taking the **full-rewrite destination** for feature composition: Den aspects/`includes`/classes/policies become the cascade graph, while **Copier** (questionnaire → `devenv.local.nix`) and the **devenv CLI** (project shell runtime) stay. Classes are `homeManager` now, a custom `project`/`devenv` class after HM dual-run proves out, and `nixos`/`darwin` later. **zen is out of scope.** Phase 1 spikes **den only** (pinned); no flake-aspects, dendrix, garden, or nest on the critical path. Watch den-diagram / import-tree only after a Phase 1 go.

## Abort criteria (cite → collapse to compositional pilot)

Stop the full-rewrite program and keep any proven HM aspects if **any** fire (from the rewrite plan):

1. **Spike failure (Phase 1):** Den `den.homes` + 2–3 aspects cannot reproduce `home-switch` for Cursor → LLM/MCP without fragile forks of HM activation / SecretSpec / mise wrappers after a bounded spike.
2. **Dual-run tax never clears (Phase 4):** After languages + cursor + terminal aspects land, shim/`imports` dual-write stays >~600 LOC *and* reviewers still grep `project.nix` / `mkIf` instead of reading `includes` DAGs.
3. **Custom class dead end (Phase 3–5):** No viable route from a Den `project`/`devenv` class into devenv’s module system without forking devenv or rewriting CI/matrix generation.
4. **Contributor / lock-in blow-up:** Den upgrades or eval complexity block template contributors for more than one release cycle with no mitigation (pin + thin adapter).
5. **Product priority flip:** Multi-OS slips indefinitely *and* cascade readability is already good enough from a language DAG alone — finish pilot cutover for HM aspects only.

## Ecosystem ranking (Phase 0 / W0.4)

| Rank | Libs | Effect |
| --- | --- | --- |
| **Adopt-with-Den** | **den** only | Sole composition dependency for Phase 1+ |
| **Watch** | den-diagram, import-tree; optionally with-inputs / flake-file / fastest | Pull only when a later phase gate shows a gap |
| **Skip** | zen (+ streams stack), flake-aspects, dendrix, garden, nest, dag, runtimes | Not rewrite deps |

## Consequences

- Phase 0 lands inventory + this ADR only — **no Den flake/npins input** yet.
- `scripts.home-switch` continues to target `home.nix` until a later phase rewires it.
- Exit of Phase 0: ready to add Den without re-debating scope or sister libs.
