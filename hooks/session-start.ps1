# Duet: at the start of each session, tells Claude that Codex is available and how to delegate tasks to it.
$utf8 = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8

$root = $env:CLAUDE_PLUGIN_ROOT ? $env:CLAUDE_PLUGIN_ROOT : (Split-Path $PSScriptRoot -Parent)
$script = Join-Path $root 'scripts/codex-task.ps1'

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
  "[Duet] Codex CLI was not found. Work on your own. Install it with: npm i -g @openai/codex, then run codex login."
  exit 0
}
$status = (& codex login status 2>&1 | Out-String).Trim()
if ($status -notmatch 'Logged in') {
  "[Duet] Codex is not logged in ($status). Work on your own. Ask the user to run: codex login."
  exit 0
}

@"
[Duet] You are working alongside Codex (ChatGPT; the user's plan limits apply, including Go). You split tasks rather than reviewing each other's work.
- Delegate to Codex: code from a clear spec, tests, bug fixes with clear reproduction steps, scripts, mechanical edits, and refactoring.
- Keep for yourself: talking with the user, planning and architecture, UI and design, writing, difficult debugging, and bringing separate pieces together.
- For every request involving code, identify an independent part for Codex and delegate it while you handle your part. Do small tasks yourself when that is faster.
- Work in separate files: list the files Codex may edit in its task, and do not edit those files while it is working.
- To delegate in the background (`run_in_background`): pwsh -NoProfile -File "$script" -Dir "<project folder>" -Task "<task: goal, files, completion criteria>"
- When Codex finishes, read its report and `git diff` for its files, run the tests, and bring the results together. No separate review is needed.
- If the output starts with CODEX_UNAVAILABLE (plan limit or error), finish the work yourself and do not invoke Codex again during this session.
- Tell the user in one sentence what Codex did.
"@
