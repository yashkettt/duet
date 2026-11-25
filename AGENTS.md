# Duet: instructions for agents editing this repository

- This is both a Claude Code plugin and a marketplace (`.claude-plugin/`). The live integration works as follows: `hooks/session-start.ps1` gives Claude task-sharing rules, `scripts/codex-task.ps1` invokes `codex exec`, and `commands/codex.md` defines the `/duet:codex` command. When making changes, bump `version` in plugin.json.

- `duet.ps1` is the PowerShell 7 orchestrator. It reads `tasks.md`, invokes `claude -p` or `codex exec`, commits to a `duet/<id>` branch in the project, and writes `notes/<id>.md`.
- `config.json` contains routes by task type and settings. `prompts/worker.md` and `prompts/reviewer.md` are prompt templates with `{{...}}` placeholders.
- `tasks.md` and `notes/` are personal and are not in git. See `tasks.example.md` for a sample queue.
- Check orchestrator changes with `./duet.ps1 -DryRun` and a test queue in a temporary git repository, not in real projects.
- Write in English. Do not push to users' projects.
