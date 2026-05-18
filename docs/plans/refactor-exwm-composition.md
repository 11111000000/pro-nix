Цель: провести рефакторинг упаковки пакетов и сессий чтобы
1) cf19 собирался как минимальная рабочая станция emacs+EXWM
2) huawei сохранил текущее поведение и собирался из новых модулей

Подход: заменить монолитные package-list и desktop-модуль на четкие слои:
- modules/system/*  — runtime и пакеты
- modules/session/* — графические сессии (EXWM, Cinnamon, GDM), fonts, audio
- modules/emacs/*   — Emacs runtime и EXWM-session glue
- hosts/*/composition.nix — сборка хоста из слоев

План миграции:
1. Создать модули в modules/system для package-sets: runtime, dev, exwm, agent, desktop-heavy.
2. Разделить modules/pro-desktop.nix на modules/session/{login,cinnamon,fonts,audio,exwm-session}.
3. Разбить emacs/home-manager.nix на modules/emacs/{core,exwm,agent} и унифицировать provided-packages.
4. Создать hosts/cf19/composition.nix, hosts/huawei/composition.nix и переключить хосты на них постепенно.
5. Проверки: nix flake check, ./tools/surface-lint.sh, ./tools/holo-verify.sh --quick, nix build для huawei и eval для cf19.

Рабочая ветка: feature/refactor-exwm-composition (worktree ../worktree-feature-refactor-exwm-composition)

Риски и mitigations:
- Не удалять старые модули до тех пор, пока оба хоста не собраны и не проверены.
- Оставлять backward-compatible lib.mkDefault / lib.mkAfter при переезде.

Контактные пункты: modules/packages-runtime.nix, modules/pro-desktop.nix, emacs/home-manager.nix, system-packages.nix
