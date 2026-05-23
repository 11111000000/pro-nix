# Change log

## Unreleased

- Исправлен стартовый путь Emacs: `orderless` больше не попадает в completion overrides до загрузки стиля.
- `ob-mermaid` восстановлен как Nix-provided зависимость Emacs-профиля; добавлен fallback на автодоставку.
- `nodePackages.mermaid-cli` добавлен в общий runtime-набор пакетов для хостов.
