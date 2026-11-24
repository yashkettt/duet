---
description: Отдать задачу Codex (ChatGPT) прямо сейчас
argument-hint: <что сделать>
---

Отдай эту задачу Codex через плагин Дуэт: $ARGUMENTS

Сформулируй для Codex чёткое ТЗ: цель, какие файлы трогать, критерий готовности. Запусти в фоне (run_in_background):

pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-task.ps1" -Dir "<текущая папка проекта>" -Task "<ТЗ>"

Пока Codex работает, не правь его файлы. Когда закончит, коротко передай пользователю его отчёт и что изменилось (git diff --stat). Если вывод начинается с CODEX_UNAVAILABLE, скажи об этом и предложи сделать самому.
