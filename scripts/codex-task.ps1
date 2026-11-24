#Requires -Version 7
<#
.SYNOPSIS
  Отдаёт одну задачу Codex CLI и печатает его отчёт. Запускается Claude из плагина Дуэт.
.EXAMPLE
  pwsh -File codex-task.ps1 -Dir C:\proj -Task "Напиши тесты для utils.py в tests/test_utils.py"
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
if (-not $Task) { 'CODEX_UNAVAILABLE: пустая задача'; exit 2 }
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) { 'CODEX_UNAVAILABLE: codex не установлен'; exit 2 }

$prompt = @"
Ты работаешь в паре с Claude Code через «Дуэт». Claude отдал тебе часть работы и параллельно делает свою.

Задача:
$Task

Правила:
- Трогай только файлы, нужные для этой задачи (если они перечислены, то только их). Остальное правит Claude.
- Не делай git commit, push и не переключай ветки.
- Сохраняй файлы в UTF-8 без BOM.
- Если что-то неясно, сделай разумное допущение и укажи его в отчёте.
- В конце дай короткий отчёт, до 10 строк: что сделал, какие файлы, что проверить, какие допущения.
Пиши по-русски.
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
  "CODEX_UNAVAILABLE: codex завершился с кодом $code. Лог: $log`n$tail"
  exit 1
}
"[Codex] отчёт ($last):"
Get-Content $last -Raw
