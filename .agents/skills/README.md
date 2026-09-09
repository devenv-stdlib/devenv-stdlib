# Vendored agent skills

Cursor loads every `*/SKILL.md` here (project skills). The files are upstream
copies installed with the [Vercel skills CLI](https://github.com/vercel-labs/skills);
`skills-lock.json` at the repo root records source and content hash.

Template checkouts refresh them with `update` (runs `npx skills update -y -p`).
Generated monorepos receive changes through `copier update`. To add or drop one:

```bash
npx skills add owner/repo --skill <name> -a cursor -y
npx skills remove <name>
```

Skills run with the agent's permissions. Review the diff of every update.

| Source | License | Skills |
| --- | --- | --- |
| [obra/superpowers](https://github.com/obra/superpowers) © Jesse Vincent | [MIT](https://github.com/obra/superpowers/blob/main/LICENSE) | `brainstorming`, `executing-plans`, `finishing-a-development-branch`, `receiving-code-review`, `requesting-code-review`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `verification-before-completion`, `writing-plans` |
| [mattpocock/skills](https://github.com/mattpocock/skills) © Matt Pocock | [MIT](https://github.com/mattpocock/skills/blob/main/LICENSE) | `code-review`, `codebase-design`, `domain-modeling`, `grill-me`, `handoff`, `implement`, `improve-codebase-architecture`, `teach`, `to-spec`, `to-tickets`, `triage`, `writing-for-agents` |
| [cursor/plugins](https://github.com/cursor/plugins) © Anysphere | MIT per plugin ([cursor-team-kit](https://github.com/cursor/plugins/blob/main/cursor-team-kit/LICENSE), [pstack](https://github.com/cursor/plugins/blob/main/pstack/LICENSE), [cli-for-agent](https://github.com/cursor/plugins/blob/main/cli-for-agent/LICENSE)) | `blast-radius`, `check-compiler-errors`, `cli-for-agents`, `deslop`, `fix-ci`, `fix-merge-conflicts`, `get-pr-comments`, `loop-on-ci`, `make-pr-easy-to-review`, `new-branch-and-pr`, `no-comments`, `principle-fix-root-causes`, `principle-prove-it-works`, `principle-subtract-before-you-add`, `review-and-ship`, `run-smoke-tests`, `technical-writing`, `typescript-best-practices`, `unslop`, `verify-this` |
| [trailofbits/skills](https://github.com/trailofbits/skills) © Trail of Bits | [CC-BY-SA-4.0](https://github.com/trailofbits/skills/blob/main/LICENSE) | `agentic-actions-auditor`, `differential-review`, `fp-check`, `gh-cli`, `modern-python`, `mutation-testing`, `property-based-testing`, `rust-review`, `second-opinion`, `sharp-edges`, `supply-chain-risk-auditor` |
| [anthropics/skills](https://github.com/anthropics/skills) © Anthropic | [Apache-2.0](mcp-builder/LICENSE.txt) | `mcp-builder` |
