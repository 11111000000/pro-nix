+++
title = "Tests"
sort_by = "weight"
template = "page.html"

[extra]
tldr = "Five test layers: VM (slow, gated), contract, unit, scenario, GUI. The whole pyramid runs in <60 s on a normal CI runner."
+++

# Tests

<span class="gen-badge">auto-gen</span> Generated 2026-06-16 from `tests/`.

> Five test layers. The first two (`flake check` and the unit tests) run on every PR. The rest are gated by `PRO_NIX_RUN_SLOW_CHECKS=1` or by being explicitly invoked through `just`.

## VM tests (slow, gated by PRO_NIX_RUN_SLOW_CHECKS=1)

| File | What it asserts (from header) |
|------|--------------------------------|
| `tests/vm/cf19-switch-dbus-regression.nix` | { testers, ... }: / VM regression test for the DBus live-switch cascade. / Контракт: внутри изолированной VM имитируем именно switch-ошибку на уровне / systemd Manager API и проверяем, что после reload D-Bus продолжает отвечать / на запросы |
| `tests/vm/huawei-boot.nix` | { testers, home-manager, piModule, ... }: / testers.nixosTest { / name = "huawei-boot"; / nodes.machine = { ... }: { |
| `tests/vm/huawei-boot.sh` | set -euo pipefail / export NIXPKGS_ALLOW_UNFREE=1 / exec nix build --impure 'path:/home/az/pro-nix#checks.x86_64-linux.huawei-boot' |
| `tests/vm/test-basic-activation.nix` | test-basic-activation.nix — минимальный тест активации / { testers, ... }: / testers.nixosTest { / name = "basic-activation-test"; |

## Contract tests

| File | What it asserts (from header) |
|------|--------------------------------|
| `tests/contract/ert-session.el` | ert-session.el --- ERT tests for session serialization -*- lexical-binding: t; -*- / (require 'pro-session) / (ert-deftest pro-test-session-save-exists () / "Test pro/session-save function exists." |
| `tests/contract/ert-soft-reload.el` | ert-soft-reload.el --- ERT tests for soft reload -*- lexical-binding: t; -*- / (require 'pro-reload) / (ert-deftest pro-test-reload-module-exists () / "Test pro/reload-module function exists." |
| `tests/contract/pro-network-01.sh` | set -euo pipefail / Контрактный тест: сетевой стек pro-nix. / Проверяет, что новые модули pro-hosts / pro-network / pro-ssh-clients / корректно описаны в репо: / 1. Реестр pro.hosts содержит все ожидаемые имена (single source of truth). / 2 |
| `tests/contract/pro-peer-01.sh` | set -euo pipefail / Простая контрактная проверка для pro-peer: ожидаем, что модуль упоминает / runtime-файл /var/lib/pro-peer/authorized_keys или определяет tmpfiles правило. / root="$(cd "$(dirname "$0")/../.." && pwd)" |
| `tests/contract/surface-headers.sh` | set -euo pipefail / Проверка: все модули должны содержать литературный заголовок ("# Название:") / root="$(cd "$(dirname "$0")/../.." && pwd)" / missing=0 |
| `tests/contract/test-gui-smoke.el` | Contract Proof header / Surface: Soft Reload (Emacs) / Stability: FROZEN / Invariant: INV-Surface-First / set -euo pipefail |
| `tests/contract/test-soft-reload.el` | Contract Proof header / Surface: Soft Reload (Emacs) / Stability: FROZEN / Invariant: INV-Surface-First / set -euo pipefail |
| `tests/contract/test-theme-contrast.el` | test-theme-contrast.el --- ERT tests for theme contrast -*- lexical-binding: t; -*- / (require 'ert) / (defun pro--rgb-luminance (color) / "Compute approximate luminance of COLOR (string or face color)." |
| `tests/contract/test_docker_dev.sh` | set -euo pipefail / Contract test: docker-утилиты доступны на всех 4 хостах. / Проверяет: / 1. virtualisation.docker.enable = true / 2. сеть pro-dev объявлена / 3. dev-порты открыты на trustedInterfaces / 4. docker / docker-compose / lazydo |
| `tests/contract/test_live_activation_smoke.sh` | set -euo pipefail / Smoke‑тест: выполняет non-root сборку toplevel для хоста huawei и, / при наличии systemd-nspawn, пытается выполнить упрощённую активацию внутри / контейнера. Тест падает, если в журнале во время активации встречается / с |
| `tests/contract/test_modelclient_smoke.sh` | set -euo pipefail / root="$(cd "$(dirname "$0")/../.." && pwd)" / echo "model-client smoke: verify app entrypoint exists" / if [ ! -f "$root/apps/model-client/app.py" ]; then |
| `tests/contract/test_runtime_packages.sh` | set -euo pipefail / Contract test: ensure minimal runtime packages are present in toplevel / Usage: run from repository root; requires nix with flakes enabled. / HOST=${1:-huawei} |
| `tests/contract/test_surface_health.spec` | Contract Proof header / Surface: Healthcheck / Stability: FROZEN / Invariant: INV-Traceability / set -euo pipefail |
| `tests/contract/test_system_runtime_paths.spec` | Contract Proof header / Surface: SystemRuntimePaths / Stability: FLUID / set -euo pipefail |
| `tests/contract/tor-01.sh` | set -euo pipefail / Проверка: модули, связанные с Tor, должны содержать сервисы/обеспечения прав / root="$(cd "$(dirname "$0")/../.." && pwd)" / f="$root/modules/pro-privacy.nix" |
| `tests/contract/validate-units.sh` | validate-units.sh — проверка unit-файлов NixOS в Nix store / Гарантирует, что сгенерированные unit-файлы корректны / и при 'just switch' система не упадёт / set -euo pipefail |

## Unit tests (tests/contract/unit)

| File | What it asserts (from header) |
|------|--------------------------------|
| `tests/contract/unit/01-pro-peer-basic.sh` | set -euo pipefail / root="$(cd "$(dirname "$0")/../../.." && pwd)" / echo "01: pro-peer basic checks" / This unit proof keeps the peer/security contract visible without requiring a / full system activation in CI. / NIX="nix --no-write-lock- |
| `tests/contract/unit/02-emacs-options.sh` | set -euo pipefail / root="$(cd "$(dirname "$0")/../../.." && pwd)" / echo "02: emacs-related options checks" / NIX="nix" |
| `tests/contract/unit/03-llm-tools.sh` | set -euo pipefail / root="$(cd "$(dirname "$0")/../../.." && pwd)" / echo "03: llm tools checks" / if ! rg -n "llm-lab|jupyterlab|transformers|datasets|sentencepiece|tokenizers" "$root/modules/system-package-sets-dev.nix" >/dev/null 2>&1; t |
| `tests/contract/unit/04-opencode-options.sh` | set -euo pipefail / root="$(cd "$(dirname "$0")/../../.." && pwd)" / NIX="nix" / echo "04: opencode options checks" |
| `tests/contract/unit/05-mkforce-lint-test.sh` | set -euo pipefail / echo "05: mkForce lint smoke test" / ./tools/mkforce-lint.sh / echo "05: OK" |
| `tests/contract/unit/06-pro-peer-dryrun.sh` | set -euo pipefail / root="$(cd "$(dirname "$0")/../../.." && pwd)" / tmpdir=$(mktemp -d) / trap 'rm -rf "$tmpdir"' EXIT |
| `tests/contract/unit/07-runtime-packages.sh` | set -euo pipefail / root="$(cd "$(dirname "$0")/../../.." && pwd)" / echo "07: runtime packages presence check (bashInteractive, openssh, gh, mc, python3, htop)" / NIX_CMD="nix" |
| `tests/contract/unit/08-pro-privacy-packages.sh` | set -euo pipefail / echo "08: pro-privacy packages presence check (obfs4proxy, meek-client, snowflake-client)" / NIX="nix" / out=$($NIX eval --json .#nixosConfigurations.huawei.config.environment.systemPackages 2>/dev/null || true) || true |
| `tests/contract/unit/09-system-packages-eval.sh` | set -euo pipefail / root="$(cd "$(dirname "$0")/../../.." && pwd)" / cd "$root" / echo "09: evaluate dev module package set (host-independent)" |
| `tests/contract/unit/test_nix_eval_basic.sh` | set -euo pipefail / root="$(cd "$(dirname "$0")/../../.." && pwd)" / echo "Running basic nix-eval unit tests" / Keep the unit test small and deterministic: verify that the repo exposes a / flake entrypoint and that nix can evaluate a trivia |

## Scenario tests

| File | What it asserts (from header) |
|------|--------------------------------|
| `tests/scenario/controlplane_e2e.sh` | set -euo pipefail / root="$(cd "$(dirname "$0")/../.." && pwd)" / echo "controlplane e2e: start mocked model-client, coordinator, worker in background" / start a mocked model client (simple HTTP echo) / python3 - <<'PY' & |
| `tests/scenario/example_scenario.test` | Simple vertical scenario test for pro-nix: verify headless Emacs starts and exits / set -euo pipefail / root="$(cd "$(dirname "$0")/../.." && pwd)" / if [ ! -f "$root/scripts/emacs-headless-test.sh" ]; then |

## GUI tests (Xvfb)

| File | What it asserts (from header) |
|------|--------------------------------|
| `tests/gui/gui-smoke.el` | gui-smoke.el --- basic GUI smoke checks for pro-emacs -*- lexical-binding: t; -*- / (let ((display (getenv "DISPLAY"))) / (unless display / (message "gui-smoke: no DISPLAY set; test requires Xvfb or a display") |

---

## How tests are run

```bash
nix flake check                                   # syntax + checks (fast)
PRO_NIX_RUN_SLOW_CHECKS=1 nix flake check         # + VM tests
just network-contract                             # contract test for the network layer
just headless-tests                               # Emacs ERT, headless
tools/holo-verify.sh unit                         # all 10 unit tests
tools/holo-verify.sh nixos-fast                   # unit + check-nixos-build + verify-units
```
