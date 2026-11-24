# Дуэт

Плагин для Claude Code: Claude и Codex (ChatGPT) работают в паре. Ты пишешь Claude как обычно, а он сам делит задачу и отдаёт Codex его часть: код по ТЗ, тесты, фиксы, скрипты. Пока Codex работает, Claude делает свою часть, а потом собирает результат. У каждого свои лимиты: Claude тратит лимиты подписки Claude, Codex тратит лимиты ChatGPT.

## Установка

Что нужно заранее:
- PowerShell 7 (`pwsh`) и git;
- Codex CLI: `npm i -g @openai/codex`, потом `codex login`. Работает на любом тарифе ChatGPT, включая Go.

В Claude Code:
```
/plugin marketplace add yashkettt/duet
/plugin install duet@duet
```
Репозиторий приватный, поэтому git на этом ПК должен быть залогинен в GitHub.

## Как это работает

- **Хук SessionStart.** В начале каждой сессии проверяет, что Codex установлен и залогинен, и даёт Claude правила дележа: кому что и как отдать.
- **`scripts/codex-task.ps1`.** Claude вызывает его в фоне. Скрипт запускает `codex exec` в папке проекта (песочница `workspace-write`, без коммитов) и печатает отчёт Codex.
- **`/duet:codex <задача>`.** Отдаёт задачу Codex вручную.
- Если у Codex кончился лимит или он упал, Claude видит `CODEX_UNAVAILABLE` и доделывает сам.
- Логи Codex лежат в `%TEMP%\duet\`.

## Очередь задач (необязательно)

`duet.ps1` разбирает очередь из `tasks.md` без участия Claude-сессии: каждая задача уходит в свою ветку `duet/<id>`, второй агент делает ревью. Подробности в `tasks.example.md`.
```powershell
./duet.ps1 -DryRun; ./duet.ps1
```
