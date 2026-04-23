**Pro-Nix — углублённый анализ**

Цель
- Углублённо проанализировать текущее состояние репозитория pro-nix: состав, крупные проблемные места, технические риски и конкретные рекомендации для краткосрочного и среднесрочного улучшения.

Краткая сводка (в 3 предложениях)
- Репозиторий функционален и богат на содержимое: NixOS-модули, home-manager шаблоны, Emacs/EXWM интеграция и множество вспомогательных инструментов.
- Основные проблемы: в репозитории присутствуют вложенные git-репозитории и большие vendor-артефакты (angular.js, fonts, analyse/.git, analyse/web_modules), отсутствуют стабильные CI и автоматическое тестирование Nix/Elisp, много TODO/FIXME по всему коду.
- Результат: высокий риск роста размера repo, медленные операции git, повышенная вероятность регрессий и сложная онбординг-история — требуется план исправлений и реорганизация.

1) Структура и метрики (кратко, по результатам скана)
- Большие директории: angular.js (~115M), fonts (~97M), agent-shell (~7M), analyse (~3.9M).
- Форматы: много .js (562), .el (118), .nix (25), .md (75), скриптов (.sh) и статических артефактов (ttf/pdf/png).
- TODO/FIXME: >6000 совпадений по всему дереву (включая vendor и результирующие каталоги) — это шум, требует фильтрации.

2) Наблюдаемые проблемы (конкретика)
- В прошлом в репозитории были вложенные .git каталоги (analyse/, .tao/), но они удалены/игнорированы; сохраняем наблюдение и не требуем дополнительных действий по их очистке.
- Большие бинарные/шрифтовые артефакты (fonts/*) добавляют десятки мегабайт и, возможно, не обязаны быть в VCS.
- Наличие result- и logs- директорий (например result-cf19, logs/) — артефакты сборок/результатов — не должны храниться в репозитории.
- Явные пробелы в CI: есть скелет workflow, но нет полного набора проверок (flake checks, nix-build, automated elisp tests, nix-lint, форматирование).
- Тестирование Emacs/Elisp: есть ERT тесты в test/ и agent-shell/tests, но нет интеграции в CI и нет гарантий, что byte-compile/ert проходят в CI.

3) Риски
- История репозитория: если не убрать vendor packs, размер останется большим и затруднит клонирование/CI.
- Регрессии: отсутствие интеграционных тестов для Nix-модулей означает, что правки в modules/ могут ломать хостовые конфиги.
- Без стандартизации форматирования и pre-commit хукoв поддержка качества кода будет медленной.

4) Конкретные срочные действия (next 1–2 недели)
- A. Удалить вложенные .git / превратить vendor части в submodule или flake input:
  - Проверить analyse/ и angular.js на намерение (вложенный репозиторий vs копия). Если это import — вынести как git submodule или удалить .git и добавить в .gitignore, либо упаковать как Nix-package.
  - Команда образец для удаления вложенных git-объектов (локально, с бэкапом):
    - mv analyse analyse.git-backup && git rm -r --cached analyse && mv analyse.git-backup analyse && git add analyse && git commit -m "chore: reintroduce analyse as working tree (remove nested git)"
  - Если требуется удалить историю большого файла: использовать git filter-repo или BFG для сокращения истории.
- B. Исключить result/ logs/ и подобные артефакты из VCS и добавить их в .gitignore.
- C. Создать минимальный CI pipeline (flake check + nix-build + elisp byte-compile + shellcheck + nixpkgs-fmt) — сейчас добавлен скелет, довести до рабочего состояния и включить кэширование.

5) Среднесрочные задачи (1–3 месяца)
- 1) Рефакторинг репозитория: модульная граница — выделить пакеты: pro-core (modules/), pro-emacs (emacs/), pro-analyse (analyse/) и vendor/ (отдельно или как inputs). Реализовать это через flakes или monorepo layout с submodules.
- 2) Тестирование Nix: написать nixos tests / containerized smoke tests для ключевых модулей (pro-desktop, pro-users, pro-services). Каждый тест должен проверять: конфигурация собирается (nixos-rebuild build), xsessions появляются, и минимальные systemd services стартуют в контейнере.
- 3) CI улучшения: добавить matrix (nixpkgs versions), кэш store, и artefact upload для test results.
- 4) Код-качество: настроить pre-commit с набором хуков: nixpkgs-fmt/nixfmt, shfmt, shellcheck, eslint (для analyse), emacs byte-compile и elisp checkdoc.

6) Долгосрочные цели (3–12 месяцев)
- 1) Введение pro-packages публикации: делать reproducible builds для pro-packages как Nix-derivations и хранить их как artifact/channel.
- 2) Релизная стратегия и governance: owners, релиз-календарь, CHANGELOG, SEMVER-like для модулей.
- 3) Автоматизация onboarding: создание образов devcontainer/VM с preloaded nix cache и быстрым способом запустить тестовую конфигурацию.

7) Конкретный план работ (микрозадачи) — для immediate sprint (2 недели)
- Task 1 (priority: high): Убрать вложенные .git в analyse/ и angular.js; перевести эти каталоги в submodules или удалить .git-объекты.
- Task 2 (priority: high): Добавить .gitignore правила для result- и logs- директорий; удалить их из индекса.
- Task 3 (priority: high): Довести CI workflow до рабочей версии (flake check, nix-build, shfmt/shellcheck, elisp byte-compile). Добавить cache actions.
- Task 4 (priority: medium): Добавить pre-commit конфигурацию (husky/pre-commit) для локальных разработчиков.
- Task 5 (priority: medium): Прописать в docs/plans/pro-nix-development-plan.md дорожную карту с owner-ами.

8) Ресурсы и команды (одноразовые команды для maintainer)
- Список полезных команд:
  - Проверить вложенные git папки: find . -type d -name '.git' -prune
  - Удалить большие файлы из истории: git filter-repo --path <path> --invert-paths
  - Быстрая проверка Nix сборки модуля: nix-instantiate -A system -I nixpkgs=channel:nixos-unstable
  - Локальная проверка Elisp: emacs -batch -Q --eval '(byte-recompile-directory "." 0)'

9) Следующие шаги от меня (я могу сделать прямо сейчас)
- 1) Создать docs/plans/pro-nix-development-plan.md (roadmap + приоритеты) — готов создать.
- 2) Исправить .gitignore и удалить result/ и logs/ из индекса — выполню после вашего подтверждения (это изменит git history index).
- 3) Вынести analyse/ и angular.js как submodules — требуется подтверждение, тк это меняет структуру репозитория.

Если подтверждаете, начну с Task 1 + Task 2 (удалю вложенные .git-артефакты из индекса и добавлю .gitignore правила), затем сгенерирую план в docs/plans.
