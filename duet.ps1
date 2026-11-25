#Requires -Version 7
<#
.SYNOPSIS
  Duet assigns tasks from tasks.md to Claude Code and Codex; the other agent reviews the work.
.EXAMPLE
  ./duet.ps1           # process the whole queue
.EXAMPLE
  ./duet.ps1 -Once     # process one task
.EXAMPLE
  ./duet.ps1 -DryRun   # show which agent gets each task
#>
param([switch]$Once, [switch]$DryRun)

$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$Root      = $PSScriptRoot
$TasksFile = Join-Path $Root 'tasks.md'
$NotesDir  = Join-Path $Root 'notes'
$Config    = Get-Content (Join-Path $Root 'config.json') -Raw | ConvertFrom-Json
$TaskRe    = '^- \[ \] (\w+) \| (.+?) \| (.+)$'

if (-not (Test-Path $TasksFile)) { Copy-Item (Join-Path $Root 'tasks.example.md') $TasksFile }
New-Item -ItemType Directory -Force $NotesDir | Out-Null

function Invoke-Git {
  $out = & git -C $script:Proj @args 2>&1 | Out-String
  if ($LASTEXITCODE) { throw "git $($args -join ' '): $out" }
  $out.Trim()
}

function Get-Prompt([string]$Name, [hashtable]$Vars) {
  $t = Get-Content (Join-Path $Root "prompts/$Name.md") -Raw
  foreach ($k in $Vars.Keys) { $t = $t.Replace("{{$k}}", [string]$Vars[$k]) }
  $t
}

function Invoke-Agent([string]$Agent, [string]$Prompt, [string]$Dir, [switch]$ReadOnly) {
  if ($Agent -eq 'claude') {
    $a = @('-p')
    if ($ReadOnly) { $a += '--disallowedTools', 'Edit', 'Write', 'NotebookEdit', 'Bash' }
    else           { $a += '--permission-mode', 'acceptEdits' }
    if ($Config.claude.model) { $a += '--model', $Config.claude.model }
    Push-Location $Dir
    try { $out = $Prompt | & claude @a | Out-String; $code = $LASTEXITCODE }
    finally { Pop-Location }
    if ($code) { throw "claude exited with code $code. $out" }
    return $out.Trim()
  }
  if ($Agent -eq 'codex') {
    $last = New-TemporaryFile
    $a = @('exec', '-C', $Dir, '-s', ($ReadOnly ? 'read-only' : 'workspace-write'), '-o', $last.FullName)
    if ($Config.codex.model) { $a += '-m', $Config.codex.model }
    $log = $Prompt | & codex @a 2>&1 | Out-String
    $code = $LASTEXITCODE
    $out = Get-Content $last.FullName -Raw
    Remove-Item $last.FullName -ErrorAction SilentlyContinue
    if ($code) {
      $tail = $log.Length -gt 3000 ? $log.Substring($log.Length - 3000) : $log
      throw "codex exited with code $code. $tail"
    }
    return "$out".Trim()
  }
  throw "Unknown agent: $Agent"
}

function Set-TaskLine([string]$Old, [string]$New) {
  $lines = [Collections.Generic.List[string]](Get-Content $TasksFile -Encoding utf8)
  $i = $lines.IndexOf($Old)
  if ($i -ge 0) { $lines[$i] = $New; Set-Content $TasksFile $lines -Encoding utf8 }
}

$done = 0
foreach ($line in @(Get-Content $TasksFile -Encoding utf8)) {
  if ($line -notmatch $TaskRe) { continue }
  $type = $Matches[1].ToLower(); $script:Proj = $Matches[2].Trim(); $text = $Matches[3].Trim()
  $worker = $Config.route.$type
  $reviewer = $worker -eq 'claude' ? 'codex' : 'claude'

  if ($DryRun) { Write-Host "$type → $worker (review: $reviewer) | $($script:Proj) | $text"; continue }

  $id = Get-Date -Format 'yyyyMMdd-HHmmss'
  $branch = "duet/$id"
  $note = Join-Path $NotesDir "$id.md"
  $base = $null
  try {
    if (-not $worker) { throw "Unknown type '$type'; see route in config.json" }
    if (-not (Test-Path $script:Proj)) { throw "Folder not found: $($script:Proj)" }
    Invoke-Git rev-parse --is-inside-work-tree | Out-Null
    if (Invoke-Git status --porcelain) { throw 'The project has uncommitted changes; commit or stash them' }
    $base = Invoke-Git branch --show-current
    if (-not $base) { throw 'The project is not on a branch (detached HEAD)' }
    Invoke-Git switch -c $branch | Out-Null

    Write-Host "▶ [$id] $worker is working on: $text"
    try {
      $answer = Invoke-Agent $worker (Get-Prompt 'worker' @{ TYPE = $type; TASK = $text; ID = $id }) $script:Proj
    } finally {
      Invoke-Git add -A | Out-Null
      if (Invoke-Git status --porcelain) {
        Invoke-Git -c user.name=Duet -c user.email=duet@localhost commit -m "duet($id): $text" | Out-Null
      }
    }

    $diff = Invoke-Git diff "$base..HEAD"
    if ($diff.Length -gt $Config.maxDiffChars) { $diff = $diff.Substring(0, $Config.maxDiffChars) + "`n... (diff truncated)" }
    $md = "# $id`n`n- Type: $type`n- Project: $($script:Proj)`n- Branch: $branch`n- Task: $text`n`n## Worker: $worker`n`n$answer`n"

    $verdict = 'not reviewed'
    if ($Config.crossReview) {
      Write-Host "  $reviewer is reviewing..."
      $vars = @{ TASK = $text; WORKER = $worker; ANSWER = $answer; DIFF = ($diff ? $diff : '(no files changed)') }
      $review = Invoke-Agent $reviewer (Get-Prompt 'reviewer' $vars) $script:Proj -ReadOnly
      $md += "`n## Review: $reviewer`n`n$review`n"
      $verdict = $review -match 'Verdict:\s*\**\s*(OK|ISSUES|BAD)\b' ? "review: $($Matches[1])" : 'review: see note'
    }
    Set-Content $note $md -Encoding utf8

    $hasCommits = [int](Invoke-Git rev-list --count "$base..$branch") -gt 0
    Invoke-Git switch $base | Out-Null
    if (-not $hasCommits) { Invoke-Git branch -D $branch | Out-Null; $where = 'no file changes' } else { $where = $branch }
    Set-TaskLine $line (($line -replace '^- \[ \]', '- [x]') + " → $where, $verdict (notes/$id.md)")
    Write-Host "✔ [$id] $where, $verdict"
  } catch {
    $err = ($_.Exception.Message -split "`n")[0]
    Add-Content $note "`n## Error`n`n$($_.Exception.Message)`n" -Encoding utf8
    if ($base) { try { Invoke-Git switch $base | Out-Null } catch {} }
    Set-TaskLine $line (($line -replace '^- \[ \]', '- [!]') + " → error: $err (notes/$id.md)")
    Write-Host "✖ [$id] $err" -ForegroundColor Red
  }
  $done++
  if ($Once) { break }
  Start-Sleep -Seconds 1  # avoid reusing the same ID for the next task
}
if (-not $DryRun) { Write-Host "Done. Tasks processed: $done" }
