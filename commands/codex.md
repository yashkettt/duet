---
description: Send a task to Codex (ChatGPT) right now
argument-hint: <what to do>
---

Send this task to Codex through the Duet plugin: $ARGUMENTS

Write a clear spec for Codex: goal, files to edit, and completion criteria. Run it in the background (`run_in_background`):

```powershell
pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-task.ps1" -Dir "<current project folder>" -Task "<spec>"
```

While Codex is working, do not edit its files. When it finishes, briefly share its report and what changed (`git diff --stat`) with the user. If the output starts with `CODEX_UNAVAILABLE`, tell the user and offer to do the work yourself.
