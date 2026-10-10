# Agent skills

`.agents/skills/` ships 85 upstream Cursor skills (project scope; Cursor reads that directory natively), vendored with the [Vercel skills CLI](https://github.com/vercel-labs/skills). `skills-lock.json` records each skill's source and content hash. Only a skill's name and description sit in context until the agent decides it is relevant; bodies load on demand.

## Sources

| Source                                                       | Covers                                                                                                                                                                                                                              |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [obra/superpowers](https://github.com/obra/superpowers)       | Brainstorming, plans, TDD, debugging, code review, worktrees                                                                                                                                                                        |
| [mattpocock/skills](https://github.com/mattpocock/skills)     | Spec/tickets/triage, codebase design, grill-me, handoff, two-axis `code-review`                                                                                                                                                     |
| [cursor/plugins](https://github.com/cursor/plugins)           | `cursor-team-kit` PR/CI flows, `pstack` unslop/no-comments/principles, `cli-for-agents`                                                                                                                                             |
| [trailofbits/skills](https://github.com/trailofbits/skills)   | Python/Rust review, property-based and mutation testing, differential review, supply chain and Actions auditors, second opinion                                                                                                     |
| [anthropics/skills](https://github.com/anthropics/skills)     | `mcp-builder`                                                                                                                                                                                                                       |
| [phuryn/pm-skills](https://github.com/phuryn/pm-skills)       | Release planning: `pm-execution` (PRDs, roadmaps, prioritization, pre-mortems, sprints, release notes, retros), `pm-product-discovery` (feature-request triage, assumption testing), `product-vision`, `product-strategy`            |

The per-skill table with licenses (MIT, CC-BY-SA-4.0, Apache-2.0) is `.agents/skills/README.md`. Skills run with the agent's permissions; review the diff of every update.

## Add, remove, update

```bash
skills add owner/repo --skill <name> -a cursor -y   # add one (repo root; mise PATH)
skills remove <name>
skills list
```

`skills` is a project-scope mise tool from `modules/non-nix/catalog.toml`. After adding one, list its source in `.agents/skills/README.md`; `tests/skills.bats` checks the directory, `skills-lock.json`, and attributions agree. In this publisher checkout, `update` runs `includes/update/skills.sh` (`skills update -y -p` after project `mise install`). Consumers receive skill changes by bumping `devenv-stdlib`. Git hooks skip `.agents/skills/` (vendored text).

## Not vendored

Excluded on purpose: duplicate TDD/debugging skills, Claude-Code-only bootstrap and subagent skills, hook-driven plugins (`ralph-loop`, `advisor`, `continual-learning`), Anthropic document/Claude-API skills, vendor-product skills, smart-contract and fuzzing suites, and rule bundles such as awesome-cursorrules (always-apply, stale). The rest of pm-skills (go-to-market, marketing, market research, analytics, toolkit, AI shipping) is tracked in [#194](https://github.com/devenv-stdlib/devenv-stdlib/issues/194).

- Docs: [Cursor skills](https://cursor.com/docs/skills), [agentskills.io](https://agentskills.io), [skills.sh](https://skills.sh/)
