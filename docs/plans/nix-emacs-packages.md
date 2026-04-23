# Nix-first Emacs Packages

Цель
- Зафиксировать минимальный, но достаточный набор пакетов, которые должны приходить
  из Nix для pro-nix Emacs-конфига.

Обязательные пакеты (ядро)
- consult
- vertico
- orderless
- marginalia
- corfu
- cape
- kind-icon
- consult-dash
- consult-eglot
- consult-yasnippet
- avy
- expand-region
- yasnippet
- projectile
- treemacs
- vterm
- ace-window

Системные утилиты
- ripgrep (`rg`)
- fd
- findutils (`find`)

Опциональные пакеты
- pro-tabs (если будет упакован или добавлен как локальный пакет)
- golden-ratio
- multi-vterm

Проверка
- Убедиться, что пакеты перечислены в:
  - `nix/provided-packages.nix`
  - `modules/pro-users-nixos.nix`
- После применения конфигурации проверить в Emacs:
  - `(require 'consult nil t)`
  - `(require 'vterm nil t)`
  - `(require 'consult-eglot nil t)`
- Проверить в shell:
  - `which rg`
  - `which fd`
  - `which find`

Принцип
- В первую очередь — Nix. Если пакет недоступен в Nix, он не считается частью базового красивого конфига.
