# Duet

A Claude Code plugin that lets Claude and Codex (ChatGPT) work together. You talk to Claude as usual, and Claude splits the task and sends Codex its part: implementing code from a clear spec, tests, fixes, or scripts. While Codex works, Claude handles its part, then brings the results together. Each agent uses its own plan limits: Claude uses your Claude subscription, and Codex uses your ChatGPT plan.

## Installation

Prerequisites:
- PowerShell 7 (`pwsh`) and git;
- Codex CLI: `npm i -g @openai/codex`, then `codex login`. It works with any ChatGPT plan, including Go.

In Claude Code:
```
/plugin marketplace add yashkettt/duet
/plugin install duet@duet
```
The repository is private, so git on this PC must be authenticated with GitHub.

## How it works

- **SessionStart hook.** At the start of each session, it checks that Codex is installed and logged in, then gives Claude rules for splitting and delegating tasks.
- **`scripts/codex-task.ps1`.** Claude runs this in the background. The script runs `codex exec` in the project folder (`workspace-write` sandbox, no commits) and prints Codex's report.
- **`/duet:codex <task>`.** Sends a task to Codex manually.
- If Codex runs out of plan limits or fails, Claude sees `CODEX_UNAVAILABLE` and finishes the work itself.
- Codex logs are stored in `%TEMP%\duet\`.

## Task queue (optional)

`duet.ps1` processes the queue in `tasks.md` without a Claude session: each task gets its own `duet/<id>` branch, and the other agent reviews the result. See `tasks.example.md` for details.
```powershell
./duet.ps1 -DryRun; ./duet.ps1
```
