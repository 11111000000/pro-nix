<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
### Добавление горячих клавиш

To add keybindings:
1. Edit `emacs-keys.org` in org-mode.
2. Use `org-babel-execute:org` to compile to Emacs Lisp.
3. For overrides, edit `~/.emacs.d/keys.org` with `:org` prefix.
4. Run `just install-emacs` to apply changes.

### Agent Tools

The system profile now exposes these agent commands on PATH:

- `goose`
- `aider`
- `opencode`
- `agent-shell` in Emacs

In Emacs, `C-c a` opens the main AI buffer and `C-c A` opens `agent-shell`.

See `docs/agents.md` and `docs/plans/agent-tooling.md` for setup and policy.

Rules:
- `emacs-keys.org` is the source of truth for shared keybindings.
- `~/.emacs.d/keys.org` is for user overrides only.
- Keep changes checkable in text.

Optional heavy packages (browsers, messaging, HLS, etc.) are disabled by default to keep builds small. See `docs/optional-packages.md` to enable them per-host or via Home Manager.

Emacs Lisp rules:
- Keep functions small and explicit.
- Prefer one file per concern.
- Make load order explicit when it matters.
- Treat text as the contract when the config is generated.

Keybindings are automatically loaded from `~/.emacs.d/keys.el`.

Проект pro-nix — кратко

pro-nix предоставляет переносимую NixOS конфигурацию и модульный Emacs‑слой
с фокусом на reproducibility, безопасности и agent‑workflow. Репозиторий включает
модули для peer‑сетей (Avahi, pro-peer SSH key sync), систему управления пакетами
и вспомогательные скрипты для headless Emacs verification и диагностики.

Быстрый старт — установка и запуск TUI

1. Клонируйте репозиторий:
   git clone https://github.com/11111000000/pro-nix.git
   cd pro-nix

2. Прототип TUI (Textual) можно запустить из корня репозитория:
   python3 ./tui/app.py

   Также в flake добавлено удобное приложение:
   nix run .#pro-nix

3. Для установки на NixOS хосте примените конфигурацию для выбранного хоста
   (пример для `cf19`):
   sudo nixos-rebuild switch --flake .#cf19

4. Если вы используете pro-peer (centralized keys): оператор должен доставить
   /etc/pro-peer/authorized_keys.gpg на хост (см. docs/plans/pro-peer-hardening-plan.md).

Ключевые части репозитория
- modules/pro-peer.nix — pro-peer: avahi, ssh hardening, pro-peer sync service.
- modules/pro-storage.nix — Samba/Syncthing defaults и firewall‑hardening.
- emacs/base/* — модульный Emacs‑слой, включающий UI и провайдера агентов.
- scripts/* — вспомогательные скрипты: run-samba-diagnostics.sh, pro-peer-sync-keys.sh и др.
- tui/ — Textual TUI prototype (tui/app.py).
- proctl/ — CLI‑адаптер, который используется TUI и Emacs для выполнения операций
  в стандартизированном JSON формате.

Как работать (коротко)
- Используйте TUI (nix run .#pro-nix или python3 ./tui/app.py) для: первичной настройки
  хоста (hostname, загрузка ключей), синхронизации ключей, запуска диагностики,
  просмотра логов и управления сервисами.
- Emacs: модуль emacs/pro-manage.el предоставляет базовые команды для интеграции
  с proctl; этот интерфейс расширяется параллельно с TUI.

Безопасность и привилегии
- По умолчанию все опасные операции показываются в режиме предварительного просмотра
  (dry‑run). Чтобы выполнить их из UI, требуется подтверждение и явная команда с
  повышением прав (pkexec/sudo). Все действия логируются в ~/.local/share/pro-nix/actions.log.

Документация
- docs/plans/pro-peer-hardening-plan.md — пошаговый план настроек pro-peer.
- docs/ops/samba-hardening.md — рекомендации по безопасному использованию Samba.
- docs/ops/README.md — оперативные заметки.

Если вы хотите, я могу:
 - развить TUI до полноценного Onboarding Wizard и добавить поддержку multi-host;
 - расширить Emacs интерфейс до паритета с TUI;
 - добавить тесты/CI шаги для proctl и TUI.
