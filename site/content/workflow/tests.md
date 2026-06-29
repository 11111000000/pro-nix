+++
title = "Тесты"
template = "page.html"
weight = 7

[extra]
tldr = "5 слоёв: flake check (быстрый), unit (10 скриптов), contract (5 скриптов), VM (slow, gated), GUI (Xvfb). Запускаются в CI: hds-verify, unit-ci, validate-pr. Локально: just flake-check, just headless-tests, just network-contract, tools/holo-verify.sh."

[[extra.next]]
title = "Per-host чек-лист"
url = "/workflow/per-host/"

[[extra.next]]
title = "Troubleshooting"
url = "/workflow/troubleshoot/"
+++

# Тесты

Тестовая пирамида имеет пять слоёв. Первые два запускаются на
каждом PR; остальные — gated by `PRO_NIX_RUN_SLOW_CHECKS=1` или
явным вызовом.

## Слой 1: `nix flake check` (быстрый, ~30 с)

Запускается на каждом PR через
`.github/workflows/flake-check.yml`. Делает:

* `nix flake check path:.`
* `./tools/holo-verify.sh` (оркестратор).

Ловит: синтаксические ошибки в `.nix`-файлах, `imports`,
указывающие на отсутствующие файлы, несуществующие опции, и
большинство багов тулчейн-скриптов.

`nix flake check` **не** достаточно — он не ловит баги
`writeShellScript`, которые проявляются только при `nix run`, и
не ловит `imports = [ ./broken.nix ]` в test-файле, не
подключённом к `flake.nix#checks`. См. [Анти-паттерны](conventions/anti-patterns.md)
для полного списка.

## Слой 2: unit-тесты (10 скриптов, <5 с всего)

`tools/holo-verify.sh unit` запускает `tests/contract/unit/*`:

| Файл | Что проверяет |
|------|---------------|
| `01-pro-peer-basic.sh` | `pro-peer.nix` объявляет `enableKeySync`, `keySyncInterval`, `keysGpgPath` |
| `02-emacs-options.sh` | `home-manager.extraSpecialArgs` вычисляется |
| `03-llm-tools.sh` | `system-package-sets-dev.nix` ссылается на `llm-lab` / `jupyterlab` / `transformers` / `datasets` / `sentencepiece` / `tokenizers` |
| `04-opencode-options.sh` | `programs.opencode-bwrap.enable = true` и `.package` непуст на юзере `az`, хост `huawei` |
| `05-mkforce-lint-test.sh` | `tools/mkforce-lint.sh` запускается (smoke) |
| `06-pro-peer-dryrun.sh` | `scripts/ops-pro-peer-sync-keys.sh --dry-run` НЕ пишет output-файл; `gpg` должен быть в PATH |
| `07-runtime-packages.sh` | `huawei` `systemPackages` содержит `gh`, `mc`, `python3`, `htop` |
| `08-pro-privacy-packages.sh` | `huawei` `systemPackages` содержит `obfs4`, `meek`, `snowflake` |
| `09-system-packages-eval.sh` | `system-package-sets-dev.nix` вычисляется; результат содержит `direnv`, `bat`, `git`, `cmake` |
| `test_nix_eval_basic.sh` | `flake.nix` существует; тривиальный `nix eval --expr '{r=1+1;}'` работает |

Эти запускаются через `.github/workflows/unit-ci.yml` на каждом
PR.

## Слой 3: contract-тесты (5 скриптов, <5 с всего)

* `tests/contract/pro-network-01.sh` — 5 чеков: `pro.hosts` имеет
  4 записи, `pro-network` настраивает Avahi + nss-mdns,
  `pro-ssh-clients` генерит `ssh_config.d/pro.conf`, headscale
  имеет `base_domain`/`magic_dns`/`prefix_v4`/`derp`, только
  `desktop` имеет `headscale.enable = true`.
* `tests/contract/pro-peer-01.sh` — `pro-peer.nix` ссылается на
  `/var/lib/pro-peer/authorized_keys`.
* `tests/contract/tor-01.sh` — `pro-privacy.nix` ссылается на
  `tor-ensure-perms` или `/var/lib/tor`.
* `tests/contract/surface-headers.sh` — каждый `modules/*.nix`
  имеет `# Название:` шапку.
* `tests/contract/test_docker_dev.sh` — 6 чеков: docker-мост
  172.20.0.0/16, firewall-порты 3000/5000/5173/8000/8080/8443 на
  `lo`, system-пакеты включают `lazydocker` / `dive` / `ctop` /
  `trivy` / `hadolint` / `sops` / `age`, Emacs `docker` в
  `providedPackages`.
* `tests/contract/test_runtime_packages.sh` — `pi` / `pi-dev`
  обёртки в `systemPackages`, `--help` возвращает 0.
* `tests/contract/test_live_activation_smoke.sh` — собирает
  `huawei` toplevel, запускает `nspawn switch-to-configuration`,
  проверяет отсутствие `Rejected send message`.
* `tests/contract/test_system_runtime_paths.spec` — `bash` и
  `ssh` существуют в `$out/sw/bin/`.
* `tests/contract/test_surface_health.spec` — `just` доступен
  или `scripts/emacs-sync.sh` существует.

Запускается через `just network-contract` (запускает
`pro-network-01.sh`).

## Слой 4: VM-тесты (slow, ~10 мин всего)

Gated by `PRO_NIX_RUN_SLOW_CHECKS=1`:

| Тест | Что проверяет |
|------|---------------|
| `tests/vm/huawei-boot.nix` | Huawei VM загружается чисто: нет `Got disconnect on API bus`, нет `Failed to activate service 'org.freedesktop.systemd1'`, нет `Unknown group "netdev"`, нет `parse failure`; `dbus-broker` и `NetworkManager` активны |
| `tests/vm/test-basic-activation.nix` | `pro-privacy.nix` activation генерит валидный `tor-ensure-bridges.service` и `tor-ensure-perms.service`; нет `Unbalanced quoting`; `ExecStart` содержит `/nix/store` path |
| `tests/vm/cf19-switch-dbus-regression.nix` | `busctl Ping`/`ListUnits` baseline OK; после `systemctl daemon-reload`, DBus всё ещё резолвит systemd manager; нет `Rejected send message` |

Используют NixOS test framework. **Slow** потому что NixOS VM
загрузка + активация занимает 1-3 минуты на тест.

Запуск:

```bash
PRO_NIX_RUN_SLOW_CHECKS=1 nix flake check
```

Или явно:

```bash
nix build ".#checks.x86_64-linux.huawei-boot"
nix build ".#checks.x86_64-linux.basic-activation-test"
nix build ".#checks.x86_64-linux.cf19-switch-dbus-regression"
```

## Слой 5: headless + GUI

* `just headless-tests` — полный headless ERT-набор, и TTY, и
  Xvfb (где применимо). Логи в `logs/emacs-headless/<stamp>/`.
* `tests/contract/ert-session.el`,
  `tests/contract/ert-soft-reload.el` — ERT-тесты для
  `pro/session-save`, `pro/session-restore`, `pro/reload-module`,
  `pro/reload-all-modules`, `pro/session-save-and-restart-emacs`.
* `tests/contract/test-soft-reload.el` — проверяет, что файл
  soft-reload-модуля существует и содержит публичное API.
* `tests/contract/test-theme-contrast.el` — WCAG-подобный чек:
  `default` face foreground/background contrast ratio ≥ 3.0.
* `tests/contract/test-gui-smoke.el` — проверяет, что
  `tests/gui/gui-smoke.el` существует и `HOLO.md` ссылается на
  него.
* `tests/gui/gui-smoke.el` — headless GUI под Xvfb. Проверяет
  `(display-graphic-p)`, создаёт временный невидимый фрейм,
  запускает `pro-emacs-check-fonts` если доступен.

## Оркестратор `holo-verify`

`tools/holo-verify.sh` — единственная точка входа для «всех
тестов кроме VM». Режимы:

```bash
./tools/holo-verify.sh            # default = unit (10 тестов)
./tools/holo-verify.sh unit      # явно unit
./tools/holo-verify.sh elisp     # helper-check-elisp.sh для репо + user-модулей
./tools/holo-verify.sh nixos-fast # unit + check-nixos-build + verify-units
./tools/holo-verify.sh full      # все tests/contract/*
./tools/holo-verify.sh --help
```

Сообщает, совпадают ли ссылки `HOLO.md` на тесты с реальными
test-файлами.

## Тулзы `surface-lint` и `mkforce-lint`

```bash
./tools/surface-lint.sh                    # базовый
./tools/surface-lint.sh --check-style     # обязательные секции шапки + кириллица
./tools/surface-lint.sh --enforce-style   # то же, exit 1 при нарушении
./tools/mkforce-lint.sh                    # неблокирующие счётчики
./tools/docs-link-check.sh                 # сломанные внутренние ссылки в docs/
```

`surface-lint --check-style` — то, что поддерживает
"Назначение / Цель / Контракт / Побочные эффекты / Proof" шапку
на каждом `modules/*.nix`. Добавьте в CI как required check.

## Scenario-тесты

`tests/scenario/controlplane_e2e.sh` — стартует mock model-client
(Flask на :31415) + coordinator + worker; POSTs task в
coordinator :8080; polls `~/.local/state/agents/transcripts/$TASK_ID.json`
до 20 с; печатает transcript при успехе. Не в CI — ручной
integration-тест.

`tests/scenario/example_scenario.test` — шаблон для новых
scenario.

## CI-workflow (16 штук)

| Workflow | Что делает |
|----------|------------|
| `ci.yml` | `nixfmt`, `shellcheck`, Elisp byte-recompile в alpine |
| `change-gate.yml` | Валидирует, что тело PR содержит `Intent:` / `Pressure:` / `Surface:` / `Proof:` |
| `elisp-parens.yml` | `scripts/check-elisp-parens.el --dir=emacs` |
| `emacs-ci.yml` | Emacs 30.2 через `ericdallo/setup-emacs`, запускает smoke + ERT |
| `emacs-e2e.yml` | Nix-shell с vertico/consult/etc, запускает E2E ассерты + тесты |
| `emacs-headless.yml` | Nix emacs, запускает `emacs-headless-test.sh tty` |
| `flake-check.yml` | `nix flake check path:.` + `holo-verify.sh` |
| `gui-smoke.yml` | Xvfb + `tests/gui/gui-smoke.el` |
| `hds-verify.yml` | `holo-verify.sh` + `surface-lint.sh` + `docs-link-check.sh` |
| `holo-verify-fast.yml` | PR-scoped: `surface-lint --check-style` + `holo-verify nixos-fast` |
| `lint-and-tests.yml` | `lint-keys.sh` + `test-emacs-e2e-assertions.el` (apt emacs-nox) |
| `opencode-check.yml` | `surface-lint` (strict) + `holo-verify unit` + `opencode-smoke.sh` + headless ERT |
| `opencode-smoke.yml` | Standalone: `opencode-smoke.sh` |
| `unit-ci.yml` | Только PR: `nix flake show --json .` + `holo-verify unit` + `mkforce-lint.sh` + `09-system-packages-eval.sh` |
| `validate-pr.yml` | `nix build '.#nixosConfigurations.cf19.config.system.build.nixos-rebuild'` (60 мин таймаут) + headless E2E + holo-verify |
| `site-build.yml` | Сборка + деплой gh-pages (этот сайт) |

## Что запускается в CI для типичного PR

1. `ci.yml` (nixfmt + shellcheck + Elisp byte-recompile).
2. `change-gate.yml` (формат тела PR).
3. `flake-check.yml` (полный `nix flake check` + holo-verify).
4. `unit-ci.yml` (10 unit-тестов + `holo-verify unit` + `mkforce-lint`
   + `09-system-packages-eval.sh`).
5. `lint-and-tests.yml` (lint-keys + E2E ассерты).
6. `holo-verify-fast.yml` (`surface-lint --check-style` +
   `holo-verify nixos-fast`).
7. `surface-lint`, `docs-link-check` и остальные.

Типичный PR проходит все 7 за ~10 минут.

## Чего в CI **нет**

* `PRO_NIX_RUN_SLOW_CHECKS=1` (VM-тесты).
* `tests/scenario/controlplane_e2e.sh`.
* `tests/contract/test_live_activation_smoke.sh` (использует
  `systemd-nspawn`).
* `vm-switch-loop.sh` (ручной regression-loop).
* `safe-switch.sh` (nixos-rebuild dry-activate pre-check).
* `tools/generate-mkforce-json.sh`, `tools/generate-options-md.sh`
  (они регенерируют docs; это не тесты).

Это запускается руками перед значительными изменениями.

## Добавление нового теста

1. Решите, к какому слою: unit (маленький shell-скрипт), contract
   (средний shell-скрипт) или VM (NixOS-тест).
2. Для unit/contract: добавьте в `tests/contract/unit/` или
   `tests/contract/`. Сделайте `exit 0` на pass, `exit <code>` на
   fail с понятным сообщением.
3. Для VM: добавьте в `tests/vm/`. Используйте `nixosTest`.
4. Подключите в `flake.nix#checks` (для VM) или
   `tools/holo-verify.sh` (для unit/contract).
5. Добавьте в CI-workflow (или в новый, если тест slow).
6. Документируйте тест в [Справочник → Тесты](reference/tests.md)
   (регенерируется через `just site-regen`).
