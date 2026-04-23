# Emacs packages provided by Nix

Этот файл фиксирует список Emacs-пакетов, которые считаются поставляемыми Nix/NixOS
в этой репозитории. Корректность этого списка имеет значение для избежания
split-brain между Nix (system layer) и Emacs user layer (ELPA/MELPA).

Цель
- Пакеты, перечисленные ниже, должны быть доступны через Nix и устанавливаться
  системой (не требуя автоматической установки из MELPA при первичной загрузке).
- Пользователь может при желании установить или обновить эти пакеты из MELPA в
  своём user layer; в таком случае ответственность за возможные конфликты лежит
  на пользователе и должна быть зафиксирована в `~/.config/emacs/decisions.el`.

Как синхронизировать
- Источник истины для списка пакетов: `nix/provided-packages.nix`.
- Чтобы сгенерировать Lisp-список, который подхватывает `site-init.el`, можно
  выполнить (локально или в CI):

```
emacs --batch -l scripts/generate-provided-packages.el \
  --eval '(generate-provided-packages "nix/provided-packages.nix" "~/.config/emacs/provided-packages.el")'
```

- Репозитарный fallback (используется когда `~/.config/emacs/provided-packages.el` не доступен)
  находится в `emacs/base/provided-packages.el` и генерируется аналогично.

Политика
- Если пакет присутствует в этом списке, его версия должна управляться через Nix.
- Если пользователь хочет более свежую версию из MELPA, он может установить её в
  своём user layer, но обязан документировать решение в `decisions.el` (см.
  `docs/POLICY-EMACS.md`) чтобы избежать неявных конфликтов.

Список пакетов (из `nix/provided-packages.nix`)

- magit
- consult
- vertico
- orderless
- marginalia
- gptel
- consult-dash
- dash-docs
- consult-eglot
- consult-yasnippet
- corfu
- cape
- kind-icon
- avy
- expand-region
- yasnippet
- projectile
- treemacs
- vterm
- ace-window

Рекомендации для CI
- Рекомендуется добавить шаг в CI, который генерирует `provided-packages.el`
  из `nix/provided-packages.nix` и сравнивает его с ожидаемым списком в репозитории
  (или просто использует сгенерированный файл при запуске headless-тестов). Это
  делает видимой рассинхронизацию между Nix и Emacs layer на ранней стадии.

Ссылки
- `nix/provided-packages.nix`
- `scripts/generate-provided-packages.el`
- `emacs/base/provided-packages.el`
- `docs/POLICY-EMACS.md`
