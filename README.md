# pro-nix — модульные Nix-конфигурации: рабочая станция, кластер, VPN и Emacs

Кратко
-----
pro-nix — набор взаимосвязанных Nix-модулей, скриптов и конфигураций, цель которых
обеспечить воспроизводимую инфраструктуру: от локальной рабочей станции до
кластерных окружений и приватных сетей. Emacs и Home Manager — важная, но не
исчерпывающая часть проекта.

Ключевые области покрытия
-------------------------
- Emacs и Home Manager: `emacs/` — полный Emacs-профиль, модули и шаблоны.
- Системные пакеты: `system-packages.nix` — централизованный набор пакетов для
  рабочих станций и серверов (devtoolchain, языки, LLM/agents, медиатулзы).
- NixOS-конфигурация: `configuration.nix`, `hardware-configuration.nix`, `flake.nix` —
  профили хостов, загрузчик, ядро и системные политики.
- Модули: `modules/` — набор функциональных модулей (desktop, services, storage,
  privacy, peer, headscale, и т.д.).
- Hosts: `hosts/` — примеры конфигураций для конкретных машин (huawei, cf19 и др.).
- Скрипты: `scripts/` — вспомогательные утилиты, миграции, backup и тесты.
- Systemd и юзеры: `systemd-user-services.nix`, готовые user/systemd-юниты.
- Тесты: `test-*.nix`, E2E-скрипты для Emacs и проверки конфигурации.
- Документация: `docs/` (HOLO.md, SURFACE.md, операции, исследования).

Назначение README
-----------------
README даёт обзор содержания репозитория и указывает на ключевые места. Он
должен отражать фактический охват проекта: не только Emacs, но и систему
рабочей станции, средства для кластеров, VPN, приватные сети и инфраструктуру
для агентов/LLM.

Быстрый старт
-------------
1. Клонирование и базовая подготовка:

   git clone <repo>
   cd pro-nix

2. Локальная проверка flake и сборка (рекомендация):

   nix flake check

3. Локальные E2E-проверки Emacs (headless):

   ./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el

4. Запуск Emacs с конфигурацией pro-nix (локально):

   emacs -Q -l emacs/base/init.el

   или

   ./scripts/emacs-pro-wrapper.sh

Проверки конфигурации NixOS
--------------------------
- Перед применением `nixos-rebuild` или `just switch` выполните локальные проверки
  и тесты (см. AGENTS.md и docs/HDS). Типичная последовательность:

  1) Убедиться, что рабочее дерево чисто: `git status --short`.
  2) Запустить локальные E2E/ERT тесты (Emacs) и `nix flake check`.
  3) Проверить отсутствие дублирующих опций (например, `environment.systemPackages`).

Ключевые рабочие процессы (обзор)
---------------------------------
- Обновление systemPackages и optional-паков: правки в `system-packages.nix` и
  их консолидация в `configuration.nix`.
- Управление пользователями и sudo: `modules/pro-users.nix`.
- Сеть, приватность и VPN: `modules/pro-privacy.nix`, `modules/pro-peer.nix`,
  `modules/headscale.nix`.
- Графический стек и рабочая среда: `modules/pro-desktop.nix`.
- Хранилище и обмен файлами: `modules/pro-storage.nix`.
- Emacs и интеграции: `emacs/` (модули, шаблоны, скрипты для синхронизации
  `site-lisp` и обновления пакетов).

Документация и HDS
------------------
- HOLO (манифест): `docs/HOLO.md` — решения, инварианты, цели изменений.
- SURFACE (контракты): `docs/SURFACE.md` — публичные интерфейсы и их стабильность.
- AGENTS.md / HDS-правила: конвейер изменений и требования к Proof/Migration.

Контрибьютинг и политика изменений
----------------------------------
Для изменений, которые затрагивают публичные контракты (SURFACE) или помечены
как [FROZEN], требуется сопровождение: Intent, Pressure, SurfaceImpact и Proof.
Следуйте руководству в AGENTS.md и HDS документации в `docs/`.

Где смотреть (касательно Emacs и не только)
-------------------------------------------
- Emacs конфигурация: `emacs/base/`, `emacs/home-manager.nix`.
- System packages и обёртки: `system-packages.nix`.
- NixOS config и модули: `configuration.nix`, `modules/`.
- Скрипты и тесты: `scripts/`, `test-*.nix`.
- Документы: `docs/` (ops, research, plans).

Контакты
--------
Открывайте issues/PR. Для оперативных вопросов используйте раздел `docs/ops/README.md`.

---
Файл README.md обновлён, чтобы отражать действительный охват проекта: pro-nix
управляет всей системой рабочего места и инфраструктуры, где Emacs — важный,
но не единственный компонент.
