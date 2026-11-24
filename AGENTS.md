# Дуэт: правила для агентов, которые правят сам этот репозиторий

- Это плагин Claude Code и одновременно маркетплейс (`.claude-plugin/`). Живая связка: `hooks/session-start.ps1` даёт Claude правила дележа, `scripts/codex-task.ps1` вызывает `codex exec`, `commands/codex.md` — команда `/duet:codex`. При изменениях поднимай `version` в plugin.json.

- `duet.ps1` — дирижёр на PowerShell 7. Читает `tasks.md`, вызывает `claude -p` или `codex exec`, коммитит в ветку `duet/<id>` проекта, пишет `notes/<id>.md`.
- `config.json` — маршруты по типам задач и настройки. `prompts/worker.md` и `prompts/reviewer.md` — шаблоны промптов с плейсхолдерами `{{...}}`.
- `tasks.md` и `notes/` личные, их нет в git. Образец очереди — `tasks.example.md`.
- Изменения дирижёра проверяй через `./duet.ps1 -DryRun` и тестовую очередь на временном git-репо, а не на реальных проектах.
- Пиши по-русски. Ничего не пушь в проектах пользователя.
