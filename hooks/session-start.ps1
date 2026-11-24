# Дуэт: в начале каждой сессии сообщает Claude, что Codex рядом, и как отдавать ему задачи.
$utf8 = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8

$root = $env:CLAUDE_PLUGIN_ROOT ? $env:CLAUDE_PLUGIN_ROOT : (Split-Path $PSScriptRoot -Parent)
$script = Join-Path $root 'scripts/codex-task.ps1'

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
  "[Дуэт] Codex CLI не найден, работай один. Установка: npm i -g @openai/codex, потом codex login."
  exit 0
}
$status = (& codex login status 2>&1 | Out-String).Trim()
if ($status -notmatch 'Logged in') {
  "[Дуэт] Codex не залогинен ($status), работай один. Пользователю: codex login."
  exit 0
}

@"
[Дуэт] Ты работаешь в паре с Codex (ChatGPT, лимиты пользователя на тарифе Go). Вы делите задачи, а не проверяете друг друга.
- Codex отдавай: код по ясному ТЗ, тесты, багфиксы с понятным воспроизведением, скрипты, механические правки и рефакторинг.
- Себе оставляй: разговор с пользователем, планы и архитектуру, UI и дизайн, тексты, сложную отладку, сборку частей в целое.
- На каждый запрос с работой в коде выдели независимую часть для Codex и отдай её, пока делаешь свою. Мелочь, которая быстрее руками, делай сам.
- У вас разные файлы: в задаче для Codex перечисли, какие файлы он трогает, и сам их не правь, пока он работает.
- Как отдать (в фоне, run_in_background): pwsh -NoProfile -File "$script" -Dir "<папка проекта>" -Task "<задача: цель, файлы, критерий готовности>"
- Когда Codex закончит, прочитай его отчёт и git diff его файлов, прогони тесты и собери результат. Отдельное ревью не нужно.
- Если вывод начинается с CODEX_UNAVAILABLE (лимит, ошибка), доделай сам и до конца сессии Codex не зови.
- В ответе пользователю одной строкой скажи, что сделал Codex.
"@
