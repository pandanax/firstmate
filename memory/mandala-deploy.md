---
name: mandala-deploy
description: Mandala project deployment traps — deploy.sh vs restart_app.sh, LLM model override in vertical_overrides.json, EXPOSE/PORT alignment for YC Serverless, webhook must be manually updated on platform switch
metadata:
  type: project
---

**Для изменений в коде всегда нужен deploy.sh, не restart_app.sh.**
`restart_app.sh` перезапускает контейнер с существующим образом на сервере — код не обновляется.
`bash scripts/deploy/deploy.sh` собирает образ заново и деплоит.

**Why:** наступили на грабли 2026-07-25 — починили env, перезапустили, баг остался в образе.
**How to apply:** любое изменение в Python-коде, JSON-конфигах или зависимостях требует deploy.sh.

---

**`src/mandala/llm/vertical_overrides.json` перебивает `LLM_MODEL` из env.**
При смене имени модели (DeepSeek переименовал `deepseek-chat` → `deepseek-v4-pro`/`deepseek-v4-flash`) нужно менять JSON-файл в коде + деплоить. Менять только env недостаточно.

**Why:** симптом — "Сервис временно недоступен", в логах `passed deepseek-chat` несмотря на изменённый env.
**How to apply:** при ошибках LLM-провайдера проверять vertical_overrides.json первым делом.

Рабочие модели DeepSeek сейчас: `deepseek-v4-flash` (быстро/дёшево), `deepseek-v4-pro` (качество).

---

**`EXPOSE` в Containerfile = порт куда YC Serverless Container направляет трафик.**
`PORT` в `ENV` и `EXPOSE` обязаны совпадать. Сейчас оба = 8080.
VM-деплой через restart_app.sh явно передаёт `-e PORT=8000` и не зависит от EXPOSE.

**Why:** EXPOSE 8000 при PORT=8080 → YC шлёт на 8000, приложение слушает 8080 → Connection timed out.

---

**При смене платформы (VM ↔ Serverless) webhook Telegram не обновляется сам.**
После deploy-serverless.sh нужно вручную переключить webhook на новый URL.
Текущий рабочий webhook — на VM: `https://api.mandala-app.online/webhooks/telegram/astrology`.

**How to apply:** при деплое на Serverless — сразу обновлять webhook. При проблемах с ботом — первым делом `getWebhookInfo`.
