# pro-nix — мысль в конфигурации

Кратко
-----
pro-nix — это не просто набор Nix-модулей и скриптов. Это оформленная инженерная позиция:
воспроизводимость как политическая и техническая договорённость, модульность как способ
упорядочить сложность, и открытость как операционная ценность. Emacs и Home Manager
являются важной частью рабочего контура, но проект охватывает системные политики,
модули для приватных сетей, инструменты для кластеров и набор контрактов для безопасных
изменений.

Этот README сочетает практическую справку и краткую философию — зачем проект устроен
именно так и какие инварианты он старается сохранить.

Philosophy — принципы проекта
-----------------------------
- Воспроизводимость превыше оптимизаций: конфигурация должна давать тот же результат
  на двух машинах с одинаковой аппаратной базой.
- Один файл — одна ответственность: модули и файлы имеют чёткие контракты и минимальную
  скрытую связность.
- Surface First: публичные интерфейсы и обещания (SURFACE) документируются ДО кода,
  и изменения сопровождаются Proof (тестами/проверками).
- Change Gate: любая правка имеет Intent + Pressure + Proof + SurfaceImpact (HDS).

Архитектура и инварианты
-------------------------
- flake.nix — единый вход: хосты (`nixosConfigurations`), devshells, CI-checks и утилиты.
- configuration.nix — кросс-хостовая политика: загрузчик, kernel, i18n, базовые сервисы.
- modules/ — модульная поверхность: pro-users, pro-services, pro-privacy, pro-peer, headscale,
  pro-desktop и т.д. Каждый модуль оформлен как NixOS-модуль с опциями и docstring.
- system-packages.nix — единая точка для больших списков пакетов; параметр `enableOptional`
  контролирует тяжёлые GUI/игровые пакеты.

Инварианты, которые проект старается не нарушать
 - Core/Periphery: ядро политики (безопасность, загрузка, сеть) — стабильное; UX и heavy GUI
   — периферийные, включаемые по явному флагу.
 - Determinism: flake outputs и детерминированные бинарники используются там, где важна
   воспроизводимость (см. opencode derivation).
 - Traceability: изменения сопровождаются PR с Change Gate блоком (см. Contributing).

Quickstart — коротко
--------------------
1) Клонировать и перейти в каталог

   git clone git@github.com:11111000000/pro-nix.git
   cd pro-nix

2) Локальные проверки flake

   nix flake check

   Если падает — попробуйте `nix flake check --show-trace` и проверьте `git status`.

3) Собрать конфигурацию хоста

   nix build .#nixosConfigurations.cf19.config.system.build.toplevel

   На целевой машине применяют конфигурацию напрямую:

   sudo nixos-rebuild switch --flake .#huawei

4) Devshell для разработки

   nix develop .#devShells.x86_64-linux.default

   Devshell создаёт небольшой wrapper `./.pro-emacs-wrapper/emacs-pro` — удобный путь
   запускать Emacs с правильными путями.

5) Emacs: быстрый тест

   emacs -Q -l emacs/base/init.el
   # или рекомендуемый путь (обёртка)
   ./scripts/emacs-pro-wrapper.sh

6) Emacs headless E2E тесты

    ./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el

Базовый набор утилит
-------------------
- pro-nix поставляет минимальный набор утилит, полезных для повседневной разработки и отладки:
  - gh — GitHub CLI
  - git, wget, curl, jq — работа с репозиториями и HTTP
  - shellcheck, shfmt — проверка и форматирование shell-скриптов
  - bat — подсветка вывода и удобный просмотр файлов
  - tldr — краткие примеры использования команд
  - mc, tmux, fzf, tree — навигация и управление сессиями
  - lnav, htop, mosh — просмотр логов, мониторинг и удалённые сессии

Если вы хотите изменить этот набор, правьте system-packages.nix и создайте PR с Change Gate.

Почему flake-first?
-------------------
Flake даёт предсказуемый интерфейс между сборками и CI: одна точка входа, явные outputs,
и возможность доставить devshell/приложения/конфигурации из одного файла. В pro-nix
flake используется как контракта для хостов и для вспомогательных приложений (pro-nix TUI,
opencode-release).

Emacs в контуре
---------------
- Emacs здесь — не только редактор. Это платформа (LSP, REPL, EXWM, агенты/LLM).
- emacs/home-manager.nix и emacs/base/* формируют переносимый профиль. system-packages
  поставляет emacsRuntime, a flake devShell упрощает запуск с нужным `load-path`.
- Для исследований по LLM и агентам используйте `llm-lab`: это воспроизводимый JupyterLab-слой
  с пакетами для датасетов, трансформеров, визуализации и прототипирования RAG.

Сборка пакетов и optional-блок
------------------------------
system-packages.nix хранит базовый список пакетов и `optionalPackages` — тяжёлые GUI,
игровые платформы и крупные сервисы. По умолчанию `enableOptional = false` — это
позволяет держать серверы минимальными, а рабочие станции — полноценными.

Безопасность, приватность и сеть
-------------------------------
- pro-peer / headscale модули реализуют защищённую модель peer-discovery и синхронизацию ключей.
- Tor / obfs / yggdrasil и прочие приватные транспортные слои включены как опции —
  проект предоставляет инструменты, но не навязывает модель операций.
- Вся чувствительная информация не должна храниться в репозитории (см. AGENTS.md). Файлы
  вроде `local.nix` и `hosts/*` — места для хост-специфичных секретов (шифрование/ops).

Change Gate и HDS
------------------
pro-nix следует HDS-подходу: любые изменения, которые влияют на публичные контрактные
элементы (SURFACE, [FROZEN]) требуют оформленного Change Gate в PR:

  Intent: <одно предложение>
  Pressure: Bug | Feature | Debt | Ops
  Surface impact: (none) | touches: <SURFACE item(s)> [FROZEN/FLUID]
  Proof: tests: <команда(ы) для воспроизведения>

Если вы затрагиваете элементы с пометкой [FROZEN] — добавьте Migration план.

Testing & CI
------------
- `nix flake check` — статические и flake-based проверки.
- Emacs E2E/headless — в `scripts/`.
- flake предоставляет `apps.check-all`, который строит все хосты (`nix run .#check-all`).

Contribution — практический чек-лист
----------------------------------
1. Сформируйте ветку `feat/<short-desc>`.
2. Добавьте минимальный Change Gate в PR описание.
3. Запустите `nix flake check` и релевантные тесты локально.
4. Для изменений влияющих на `environment.systemPackages` — проверьте `rg "environment.systemPackages" -n`.
5. Откройте PR и укажите шаги для верификации.

Troubleshooting — распространённые проблемы
------------------------------------------
- "Git tree is dirty" при сборке flake: закоммитьте или stash изменения.
- Дублирование опции `environment.systemPackages`: найдите все объявления `rg "environment.systemPackages" -n`
  и объедините через `lib.mkForce` или `lib.mkDefault` аккуратно.
- Nix ошибки: повторите с `--show-trace`.

Как расширить систему: добавить хост
-----------------------------------
1. Создайте `hosts/<your-host>/configuration.nix`, импортируя `./configuration.nix`.
2. Укажите `networking.hostName`, `fileSystems`, `boot.loader` и другие host-specific параметры.
3. Прогоните локально `nix build .#nixosConfigurations.<your-host>.config.system.build.toplevel`.

Глоссарий (коротко)
--------------------
- Surface — публичная, наблюдаемая гарантия/интерфейс конфигурации.
- HOLO / AGENTS / HDS — политика изменений, workflow и проверяемые контракты (см. AGENTS.md).
- FROZEN — пометка для контрактов, которые требуют миграций/Proof при изменении.

Следующие шаги и предложения
-----------------------------
- Добавить LICENSE (если вы хотите явную лицензию — укажите какой).
- Автоматизировать CI-бейджи: привязать GitHub Actions workflows к flake checks и вставить реальные URL бейджей.
- Вынести длинный Troubleshooting и HOLO / SURFACE в `docs/` как проверяемую спецификацию.

Контакты
--------
Открывайте issues/PR. Для оперативных/ops вопросов — смотрите `docs/ops/README.md`.
