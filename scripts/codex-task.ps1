#Requires -Version 7
<#
.SYNOPSIS
  Sends one task to Codex CLI and prints its report. Run by Claude from the Duet plugin.
.EXAMPLE
  pwsh -File codex-task.ps1 -Dir C:\proj -Task "Write tests for utils.py in tests/test_utils.py"
.EXAMPLE
  pwsh -File codex-task.ps1 -Dir C:\proj -TaskFile task.md -ReadOnly
#>
param(
  [string]$Task,
  [string]$TaskFile,
  [string]$Dir = (Get-Location).Path,
  [switch]$ReadOnly,
  [string]$Model
)
$utf8 = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

if ($TaskFile) { $Task = Get-Content $TaskFile -Raw -Encoding utf8 }
if (-not $Task) { 'CODEX_UNAVAILABLE: empty task'; exit 2 }
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) { 'CODEX_UNAVAILABLE: codex is not installed'; exit 2 }

$prompt = @"
You are working alongside Claude Code through Duet. Claude has delegated part of the work to you and is working on its part in parallel.

Task:
$Task

Rules:
- Edit only the files needed for this task; if files are listed, edit only those. Claude is handling the rest.
- Do not commit, push, or switch branches.
- Save files as UTF-8 without a BOM.
- If anything is unclear, make a reasonable assumption and mention it in your report.
- At the end, give a brief report of no more than 10 lines: what you did, which files you changed, what should be checked, and any assumptions.
Write in English.
"@

$logDir = Join-Path ([IO.Path]::GetTempPath()) 'duet'
New-Item -ItemType Directory -Force $logDir | Out-Null
$id = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$last = Join-Path $logDir "$id.md"
$log = Join-Path $logDir "$id.log"

$a = @('exec', '-C', $Dir, '-s', ($ReadOnly ? 'read-only' : 'workspace-write'), '-o', $last)
if ($Model) { $a += '-m', $Model }
$prompt | & codex @a *> $log
$code = $LASTEXITCODE

if ($code -or -not (Test-Path $last)) {
  $tail = (Get-Content $log -Tail 15 -ErrorAction SilentlyContinue) -join "`n"
  "CODEX_UNAVAILABLE: codex exited with code $code. Log: $log`n$tail"
  exit 1
}
"[Codex] Report ($last):"
Get-Content $last -Raw
