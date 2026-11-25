# Task queue

One task per line: `- [ ] type | project folder | what to do`
Statuses: `[ ]` pending, `[x]` done, `[!]` error. The orchestrator only picks up `[ ]`.
Types: plan, text, design, review → Claude; code, test, fix → Codex (configured in config.json).
The project must be a git repository with no uncommitted changes.

<!-- Example:
- [ ] code | C:\Users\iamya\Documents\ChatGPT\Client Search | Add a "How to run locally" section to the README
-->
