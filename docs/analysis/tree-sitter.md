Title: Tree-sitter / LSP integration analysis

Цель
- Собрать текущую информацию по доступным библиотекам/пакетам tree-sitter и language-servers в контексте этого репозитория и NixOS (nixpkgs/nixos-25.11).
- Предложить рабочий план для того, чтобы при `just switch` (systemPackages / home-manager) устанавливалиcь требуемые LSP и tree-sitter grammar so-файлы для Emacs (treesit).

Содержимое репозитория — что найдено
- Emacs-конфиг в `emacs/base/modules` использует `js-ts-mode`, `typescript-ts-mode`, `tsx-ts-mode` (файл `pro-js.el`). Это означает, что проект ожидает доступность tree-sitter парсеров для typescript/tsx.
- В flake.nix devShell и emacs-пакеты включают `emacsPkg` и много emacs-extensions (eglot, consult-eglot и т.д.).
- В логах (logs/) и сообщениях видно, что Emacs ищет `libtree-sitter-typescript` и `libtree-sitter-tsx` в `/nix/store/...-emacs-packages-deps/lib/` и в `~/.config/emacs/tree-sitter/` — но файлы отсутствуют.
- Также eglot жалуется на отсутствие `typescript-language-server` в PATH.

Найденные внешние ресурсы и пакеты
- tree-sitter grammars:
  - https://github.com/tree-sitter/tree-sitter-typescript (typescript/tsx)
  - https://github.com/tree-sitter/tree-sitter (ядро)
  - Прочие grammar-репозитории можно найти на GitHub или в пакете `tree-sitter-langs`.
- В nixpkgs / NixOS: стандартный подход — использовать `tree-sitter-cli` для генерации парсеров и собирать .so как derivation.
  - Также есть пакеты nodePackages.typescript-language-server доступные в nixpkgs (typescript-language-server) — их следует добавить в systemPackages или user profile.

Варианты интеграции (анализ)
1) Runtime install (быстро)
   - Emacs: `M-x treesit-install-language-grammar` или пакет `tree-sitter-langs` (если доступен) скачает и соберёт библиотеки в `~/.config/emacs/tree-sitter/`.
   - Плюсы: просто в интерактивном сценарии.
   - Минусы: не воспроизводимо для NixOS-сборок, не работает в headless/CI/sandbox без дополнительных прав.

2) Build-time через Nix (рекомендованный)
   - Создать Nix-деривацию `nix/treesitter-grammars.nix` которая для каждого языка:
     * скачивает grammar (github)
     * использует `tree-sitter-cli` / gcc для сборки `libtree-sitter-<lang>.so`
     * помещает .so в $out/lib
   - Добавить эту деривацию в `environment.systemPackages` или в `home-manager` пакеты так, чтобы Emacs запускался с этими библиотеками в LD_LIBRARY_PATH или чтобы Emacs мог найти их в стандартных местах `/nix/store/.../lib`.
   - Плюсы: воспроизводимо, работает в CI и при `just switch`.
   - Минусы: требуется написать и протестировать Nix сборку (несколько часов работы), возможно доп. патчи для grammars.

3) Включить грамматики в emacsPackages-overlay
   - Альтернатива: создать overlay для emacsPackages, который добавляет зависимости на готовую сборку грамматик; Emacs package build может затем включать путь в emacsPackages-deps.
   - Плюсы/минусы: похоже на вариант 2, но интегрируется с emacsPackages.

Рекомендованный минимальный план (конкретные шаги)
1. Добавить LSP-серверы в systemPackages (минимум для JavaScript/TypeScript):
   - `nodePackages.typescript-language-server`
   - `nodePackages.typescript`
   (опционально `vscode-langservers-extracted` / `typescript-language-server` зависимости).
   Где: `system-packages.nix` или `flake.nix` -> `systemPackages`.

2. Написать простую Nix-деривацию `nix/treesitter-grammars.nix` для typescript/tsx:
   - Использовать `tree-sitter-cli` (pkgs.tree-sitter-cli) и `gcc`.
   - Сборка: `tree-sitter generate` + `gcc -shared -fPIC src/parser.c -o $out/lib/libtree-sitter-<lang>.so`.
   - Добавить результат в `environment.systemPackages`.

3. Тесты / проверка:
   - После `just switch`: убедиться, что `which typescript-language-server` возвращает путь.
   - Запустить headless Emacs (`./scripts/emacs-verify.sh both` или `just headless`) и проверить отсутствие ошибок treesit в логах и наличие `treesit-language-available-p 'typescript`.

Ссылки и источники (поиск / справка)
- tree-sitter: https://github.com/tree-sitter/tree-sitter
- tree-sitter-typescript: https://github.com/tree-sitter/tree-sitter-typescript
- Примеры сборки grammar в Nix: найти в nixpkgs выражения для `tree-sitter`/`tree-sitter-cli` и поискать пакеты `tree-sitter-grammars` (в nixpkgs иногда есть `tree-sitter` parsers packaged for editors).

Следующие шаги (если нужно реализовать)
1) Согласуйте target: system-wide или home-manager per-user.
2) Уточните список языков (минимум: typescript, tsx; желательные: javascript, python, rust, go).
3) Я создам Nix-деривацию `nix/treesitter-grammars.nix` + патч во `flake.nix` / `system-packages.nix` и запущу локальные проверки (`just flake-check`, headless Emacs tests).

Автор: OpenCode (агент)
