#Requires -Version 7
<#
.SYNOPSIS
  Дуэт: раздаёт задачи из tasks.md агентам Claude Code и Codex, второй агент делает ревью.
.EXAMPLE
  ./duet.ps1           # пройти всю очередь
.EXAMPLE
  ./duet.ps1 -Once     # выполнить одну задачу
.EXAMPLE
  ./duet.ps1 -DryRun   # только показать, кому что уйдёт
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
    if ($code) { throw "claude завершился с кодом $code. $out" }
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
      throw "codex завершился с кодом $code. $tail"
    }
    return "$out".Trim()
  }
  throw "неизвестный агент: $Agent"
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

  if ($DryRun) { Write-Host "$type → $worker (ревью: $reviewer) | $($script:Proj) | $text"; continue }

  $id = Get-Date -Format 'yyyyMMdd-HHmmss'
  $branch = "duet/$id"
  $note = Join-Path $NotesDir "$id.md"
  $base = $null
  try {
    if (-not $worker) { throw "неизвестный тип «$type», см. route в config.json" }
    if (-not (Test-Path $script:Proj)) { throw "нет папки $($script:Proj)" }
    Invoke-Git rev-parse --is-inside-work-tree | Out-Null
    if (Invoke-Git status --porcelain) { throw 'в проекте есть незакоммиченные изменения, закоммить или спрячь их' }
    $base = Invoke-Git branch --show-current
    if (-not $base) { throw 'проект не на ветке (detached HEAD)' }
    Invoke-Git switch -c $branch | Out-Null

    Write-Host "▶ [$id] $worker делает: $text"
    try {
      $answer = Invoke-Agent $worker (Get-Prompt 'worker' @{ TYPE = $type; TASK = $text; ID = $id }) $script:Proj
    } finally {
      Invoke-Git add -A | Out-Null
      if (Invoke-Git status --porcelain) {
        Invoke-Git -c user.name=Duet -c user.email=duet@localhost commit -m "duet($id): $text" | Out-Null
      }
    }

    $diff = Invoke-Git diff "$base..HEAD"
    if ($diff.Length -gt $Config.maxDiffChars) { $diff = $diff.Substring(0, $Config.maxDiffChars) + "`n... (дифф обрезан)" }
    $md = "# $id`n`n- Тип: $type`n- Проект: $($script:Proj)`n- Ветка: $branch`n- Задача: $text`n`n## Исполнитель: $worker`n`n$answer`n"

    $verdict = 'без ревью'
    if ($Config.crossReview) {
      Write-Host "  $reviewer проверяет..."
      $vars = @{ TASK = $text; WORKER = $worker; ANSWER = $answer; DIFF = ($diff ? $diff : '(файлы не менялись)') }
      $review = Invoke-Agent $reviewer (Get-Prompt 'reviewer' $vars) $script:Proj -ReadOnly
      $md += "`n## Ревью: $reviewer`n`n$review`n"
      $verdict = $review -match 'Вердикт:\s*\**\s*([^\r\n*]+)' ? "ревью: $($Matches[1].Trim())" : 'ревью: см. заметку'
    }
    Set-Content $note $md -Encoding utf8

    $hasCommits = [int](Invoke-Git rev-list --count "$base..$branch") -gt 0
    Invoke-Git switch $base | Out-Null
    if (-not $hasCommits) { Invoke-Git branch -D $branch | Out-Null; $where = 'без изменений в файлах' } else { $where = $branch }
    Set-TaskLine $line (($line -replace '^- \[ \]', '- [x]') + " → $where, $verdict (notes/$id.md)")
    Write-Host "✔ [$id] $where, $verdict"
  } catch {
    $err = ($_.Exception.Message -split "`n")[0]
    Add-Content $note "`n## Ошибка`n`n$($_.Exception.Message)`n" -Encoding utf8
    if ($base) { try { Invoke-Git switch $base | Out-Null } catch {} }
    Set-TaskLine $line (($line -replace '^- \[ \]', '- [!]') + " → ошибка: $err (notes/$id.md)")
    Write-Host "✖ [$id] $err" -ForegroundColor Red
  }
  $done++
  if ($Once) { break }
  Start-Sleep -Seconds 1  # чтобы id следующей задачи не совпал
}
if (-not $DryRun) { Write-Host "Готово, задач обработано: $done" }
