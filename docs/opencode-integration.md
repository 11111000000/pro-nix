Opencode — установка
=====================

Установка
---------
1. `pipx install opencode`
2. `npm install -g @opencode/cli`
3. Локальный бинарник в `~/.local/bin/opencode`

Ключи
-----
- Не храните API-ключи в Nix-конфигах.
- Для Emacs лучше использовать `auth-source`.
- Если нужен `AITUNNEL_KEY`, подставляйте его в рантайме.

Проверка
--------
- `which opencode`
- `opencode --version`
