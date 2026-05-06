SURFACE — реестр публичных контрактов
====================================

Описание
--------
Каждая запись описывает наблюдаемое, проверяемое поведение репозитория и указывает
Proof — конкретную команду или тест, обеспечивающие воспроизводимую проверку этого
поведения. Для записей с пометкой [FROZEN] любые изменения требуют Change Gate
с миграцией и соответствующими Proof.

Записи
------

Ниже перечислены публичные поверхности (Surface) репозитория. Для каждой поверхности указана стабильность, краткая спецификация и Proof — команда или тест, однозначно проверяющие поведение.

- Имя: Healthcheck
  Стабильность: [FROZEN]
  Спецификация: минимальная воспроизводимая проверка работоспособности репозитория — набор контрактных проверок, которые должны успешно выполняться в чистой среде.
  Proof: `tests/contract/test_surface_health.spec`
  Run: `./tools/surface-lint.sh && ./tools/holo-verify.sh --quick`
  Owner: `tools/surface-lint.sh`, `tests/contract`
  Last reviewed: 2026-05-04
  Risk: high

- Имя: Flake Outputs / Host Entrypoints
  Стабильность: [FROZEN]
  Спецификация: flake предоставляет воспроизводимые outputs: `nixosConfigurations`, `devShells`, `apps.check-all`. Их наличия и корректность проверяют flake-based проверки и CI.
  Proof: `nix flake check`, `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
  Run: `nix flake check && nix build .#nixosConfigurations.huawei.config.system.build.toplevel`
  Owner: `flake.nix`, `nixos/*`
  Last reviewed: 2026-05-04
  Risk: high

- Имя: Soft Reload (Emacs)
  Стабильность: [FROZEN]
  Спецификация: опция `pro.emacs.softReload.enable` обеспечивает безопасную подгрузку UI, ключевых модулей и конфигурации Emacs без полного перезапуска; поведение покрывается headless ERT тестами.
  Proof: `./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el`
  Run: `./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-run-tests.el`
  Owner: `emacs/base`, `scripts/emacs-*`, `tests/contract`
  Last reviewed: 2026-05-04
  Risk: high

- Имя: Git Worktree Policy
  Стабильность: [FLUID]
  Спецификация: все агенты (автоматические и люди), вносящие изменения в репозиторий pro-nix, обязаны работать в отдельной git worktree, а не в primary worktree. Это предотвращает случайные коммиты в операционную директорию.
  Proof: `./scripts/check-worktree.sh --help`, `./scripts/setup-worktree.sh --help` (скрипты проверяют и создают worktree); рекомендуемое preflight: `./scripts/check-worktree.sh`.
  Run: `./scripts/check-worktree.sh`
  Owner: `AGENTS.md`, `scripts/setup-worktree.sh`, `scripts/check-worktree.sh`
  Last reviewed: 2026-05-04
  Risk: medium

- Имя: Runtime Packages & Activation
  Стабильность: [FLUID]
  Спецификация: набор runtime-пакетов, необходимых для корректной активации системы и работы вспомогательных скриптов (activate, ensure-perms, helpers), включая глобальный `pi` для всех пользователей на всех хостах. Документируется в `system-packages.nix`.
  Proof: `tests/contract/test_runtime_packages.sh`, `./scripts/check-nixos-build.sh`
  Run: `./scripts/check-nixos-build.sh`
  Owner: `system-packages.nix`, `modules/*`
  Last reviewed: 2026-05-04
  Risk: medium

- Имя: NixOS Base Configuration
  Стабильность: [FROZEN]
  Спецификация: кросс-хостовая база политик (configuration.nix, модули в `modules/`), определяющая безопасные значения по умолчанию для сети, пользователей и сервисов.
  Proof: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`, `./tools/holo-verify.sh`
  Run: `nix build .#nixosConfigurations.huawei.config.system.build.toplevel`
  Owner: `configuration.nix`, `modules/`
  Last reviewed: 2026-05-04
  Risk: high

- Имя: Boot / Kernel Policy
  Стабильность: [FLUID]
  Спецификация: политика выбора загрузчика/ядра и опций (secure-boot, kernelPackages, initrd) для поддерживаемых хостов.
  Proof: `nix eval --json .#nixosConfigurations.<host>.boot.loader`, `./scripts/check-nixos-build.sh`
  Run: `nix eval --json .#nixosConfigurations.huawei.config.boot.loader`
  Owner: `nixos/*`, `modules/*`
  Last reviewed: 2026-05-04
  Risk: medium

- Имя: Users & Sudo
  Стабильность: [FLUID]
  Спецификация: декларативное управление пользователями, группами и sudo-политиками через NixOS/Home-Manager модули.
  Proof: `nix eval --json .#nixosConfigurations.<host>.users.users`, `tests/contract/unit/02-user-basic.sh`
  Run: `nix eval --json .#nixosConfigurations.huawei.config.users.users`
  Owner: `modules/pro-users.nix`, `emacs/home-manager.nix`
  Last reviewed: 2026-05-04
  Risk: medium

- Имя: Network & Security Stack
  Стабильность: [FLUID]
  Спецификация: конфигурации сетевых адаптеров, firewall, host-based VPN (WireGuard), Tor/Yggdrasil и соответствующие политики приватности.
  Proof: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`, модульные unit-тесты и `./tools/holo-verify.sh`
  Run: `./tools/holo-verify.sh --nixos-fast`
  Owner: `modules/*`, `nixos/modules/*`
  Last reviewed: 2026-05-04
  Risk: high

- Имя: Desktop / EXWM
  Стабильность: [FLUID]
  Спецификация: декларативная конфигурация рабочего стола (EXWM, display-manager, X/Wayland настройки) для поддерживаемых хостов.
  Proof: headless ERT + локальные smoke-tests (`./scripts/test-emacs-headless.sh`)
  Run: `./scripts/test-emacs-headless.sh`
  Owner: `emacs/base`, `modules/pro-desktop.nix`
  Last reviewed: 2026-05-04
  Risk: low

- Имя: Portable Emacs Runtime
  Стабильность: [FLUID]
  Спецификация: переносимый Emacs-профиль, site-lisp и runtime-обвязка, используемые как локально, так и в devShell.
  Proof: `./scripts/emacs-pro-wrapper.sh --version`, `emacs/base/tests`
  Run: `./scripts/emacs-pro-wrapper.sh --version`
  Owner: `emacs/base`, `emacs/home-manager.nix`
  Last reviewed: 2026-05-04
  Risk: medium

- Имя: Emacs Runtime State Hygiene
  Стабильность: [FLUID]
  Спецификация: разделение конфигурации, долговечного состояния и кэша для pro-Emacs:
    - Конфигурация: `~/.config/emacs`
    - Долговечное состояние: `~/.local/state/pro-emacs`
    - Кэш/временные файлы: `~/.cache/pro-emacs`
  Proof: `emacs/base/tests/test-history.el`, `./scripts/test-emacs-headless.sh tty`
  Run: `emacs --batch -l emacs/base/tests/test-history.el`
  Owner: `emacs/base/modules/pro-history.el`, `emacs/home-manager.nix`
  Last reviewed: 2026-05-04
  Risk: low

- Имя: Emacs Package Resolution
  Стабильность: [FLUID]
  Спецификация: порядок и политика разрешения пакетов (gnu, nongnu, melpa), приоритет вручную установленных пакетов над Nix-provided; `package-refresh-contents` выполняется по необходимости.
  Proof: `./scripts/test-run-emacs-e2e.sh`
  Run: `./scripts/test-run-emacs-e2e.sh`
  Owner: `emacs/base/init.el`, `emacs/base/modules/pro-packages.el`, `emacs/base/tests`
  Last reviewed: 2026-05-04
  Risk: medium

- Имя: Emacs Lisp Module Syntax
  Стабильность: [FLUID]
  Спецификация: отдельная проверка синтаксиса Emacs Lisp-модулей без запуска общей `holo-verify --quick`; читает верхнеуровневые формы и ловит ошибки чтения.
  Proof: `./tools/holo-verify.sh elisp`
  Run: `./tools/holo-verify.sh elisp`
  Owner: `tools/holo-verify.sh`, `scripts/helper-check-elisp.sh`
  Last reviewed: 2026-05-06
  Risk: low

- Имя: Emacs AI / Agent Shell
  Стабильность: [FLUID]
  Спецификация: портированная интеграция для агентной работы внутри Emacs (pro-agent-shell, pro-ai), entrypoints и helper-скрипты.
  Proof: локальные модульные тесты `emacs/base/tests`, smoke scripts
  Run: `emacs --batch -l emacs/base/tests/test-agent-shell.el`
  Owner: `emacs/base/modules/pro-ai.el`, `emacs/base/modules/pro-agent-shell.el`
  Last reviewed: 2026-05-04
  Risk: low

- Имя: Pro-peer Key Sync
  Стабильность: [FLUID]
  Спецификация: механизм распространения/синхронизации authorized_keys между доверенными хостами; управляется systemd unit-ом и вспомогательными скриптами.
  Proof: `scripts/pro-peer-sync-keys.sh --help`, `tests/contract/unit/01-pro-peer-basic.sh`
  Run: `scripts/pro-peer-sync-keys.sh --help`
  Owner: `scripts/pro-peer-*.sh`, `modules/pro-peer.nix`
  Last reviewed: 2026-05-04
  Risk: high

- Имя: Privacy Transports (Tor / Yggdrasil / WireGuard)
  Стабильность: [FLUID]
  Спецификация: опции и модули, обеспечивающие приватность и изоляцию сетевого трафика (Tor, Yggdrasil, WireGuard helpers).
  Proof: модульные smoke-тесты и `./tools/holo-verify.sh`
  Run: `./tools/holo-verify.sh --nixos-fast`
  Owner: `modules/pro-privacy.nix`, `nixos/modules/*`
  Last reviewed: 2026-05-04
  Risk: high

- Имя: Samba / SMB / Syncthing Integrations
  Стабильность: [FLUID]
  Спецификация: модули и скрипты для обмена файлами (samba, syncthing), ключи/пароли встраиваются через внешние операционные процессы (ops scripts).
  Proof: `bash scripts/mount-smb.sh --help`, unit-tests в `tests/contract`
  Run: `bash scripts/mount-smb.sh --help`
  Owner: `nixos/modules/pro-smb-*`, `scripts/`
  Last reviewed: 2026-05-04
  Risk: low

- Имя: SMB Mount Tooling / Automount
  Стабильность: [FLUID]
  Спецификация: утилиты авто-монтирования и управление учетными данными для сетевых шар.
  Proof: `scripts/mount-smb.sh --help`, `tests/contract/unit/04-smb-automount.sh`
  Run: `scripts/mount-smb.sh --help`
  Owner: `nixos/modules/pro-smb-automount.nix`, `scripts/mount-smb.sh`
  Last reviewed: 2026-05-04
  Risk: low

- Имя: Opencode Delivery & Agent Resource Controls
  Стабильность: [FLUID]
  Спецификация: delivery pipeline для opencode, ограничение ресурсов (systemd slices, opencode.slice) для изолированных задач агентов/сборок.
  Proof: `nix build .#packages.x86_64-linux.opencode`, `systemd-analyze verify` на unit-файлах, smoke-tests
  Run: `nix build .#packages.x86_64-linux.opencode`
  Owner: `modules/opencode.nix`, `systemd-user-services.nix`
  Last reviewed: 2026-05-04
  Risk: medium

- Имя: zram / Swap Policy
  Стабильность: [FLUID]
  Спецификация: политика конфигурации zram и swap для хостов с ограниченными ресурсами.
  Proof: `nix eval --json .#nixosConfigurations.<host>.config.systemd.services.zram`, unit-tests
  Run: `nix eval --json .#nixosConfigurations.huawei.config.systemd.services.zram`
  Owner: `modules/zram-slice.nix`
  Last reviewed: 2026-05-04
  Risk: low

- Имя: llm-lab / Model Entrypoints
  Стабильность: [FLUID]
  Спецификация: воспроизводимые entrypoint-ы для исследований с LLM (llm-lab), включая Jupyter и вспомогательные скрипты.
  Proof: `tests/contract/unit/03-llm-tools.sh`, `./scripts/llm-lab-smoke.sh`
  Run: `./scripts/llm-lab-smoke.sh`
  Owner: `apps/`, `tests/contract`
  Last reviewed: 2026-05-04
  Risk: low

- Имя: model-client / experiment tooling
  Стабильность: [FLUID]
  Спецификация: клиентские утилиты и API-обертки для взаимодействия с моделями и экспириентами.
  Proof: unit-tests, smoke scripts in `tests/contract`
  Run: `./tests/contract/test_modelclient_smoke.sh`
  Owner: `apps/model-client`, `tests/contract`
  Last reviewed: 2026-05-04
  Risk: low

- Имя: headscale / tailscale helpers
  Стабильность: [FLUID]
  Спецификация: поддержка headscale и helper-скриптов для приватных сетевых подключений.
  Proof: module smoke-tests, `nix build .#packages.headscale`
  Run: `nix build .#packages.headscale`
  Owner: `modules/*`, `packages/`
  Last reviewed: 2026-05-04
  Risk: low

- Имя: CUDA / HW Overlays
  Стабильность: [FLUID]
  Спецификация: overlay-и и опции для конфигурации GPU-ускорения (CUDA), привязанные к хосту.
  Proof: `nix build .#packages.cuda-overlay`, hardware smoke-tests
  Run: `nix build .#packages.cuda-overlay`
  Owner: `packages/`, `nixos/modules/*`
  Last reviewed: 2026-05-04
  Risk: low

- Имя: Verification Tooling & CI Proofs
  Стабильность: [FROZEN]
  Спецификация: локальные и CI-утилиты, которые проверяют соответствие SURFACE/HOLO контрактам (surface-lint, holo-verify, flake checks).
  Proof: `./tools/surface-lint.sh`, `./tools/holo-verify.sh`, `nix flake check`
  Run: `./tools/surface-lint.sh && ./tools/holo-verify.sh --quick`
  Owner: `tools/`, `tests/contract`
  Last reviewed: 2026-05-04
  Risk: high

- Имя: Systemd Unit Verification
  Стабильность: [FLUID]
  Спецификация: единая политика генерации systemd unit-файлов и проверка их корректности (`systemd-analyze verify`).
  Proof: `systemd-analyze verify <unit-file>`, `./tools/holo-verify.sh`
  Run: `./scripts/verify-units.sh`
  Owner: `systemd-user-services.nix`, `modules/`
  Last reviewed: 2026-05-04
  Risk: medium

- Имя: Live Activation Preflight
  Стабильность: [FROZEN]
  Спецификация: обязательные preflight-проверки перед `nixos-rebuild switch`/`just switch`: вычислимость профиля пакетов и тесты system-packages.
  Proof: `nix --extra-experimental-features 'nix-command flakes' eval --json .#nixosConfigurations.<host>.config.environment.systemPackages`, `tests/contract/unit/09-system-packages-eval.sh`
  Run: `./scripts/helper-check-nixos-build.sh huawei`
  Owner: `scripts/check-worktree.sh`, `tests/contract`
  Last reviewed: 2026-05-04
  Risk: high

Как пользоваться
---------------
1. Для просмотра всех публичных записей используйте этот файл — SURFACE.md.
2. Перед изменением любой записи с пометкой [FROZEN] оформляйте Change Gate в PR
   (Intent, Pressure, Surface impact, Proof, Migration если необходимо).
