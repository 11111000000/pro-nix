Оптимальные планы улучшений (с приоритетами и шагами)
=====================================================

Цель: дать практический набор планов (short/medium/long) для повышения надёжности,
воспроизводимости и соответствия HDS в pro-nix. Каждый план содержит: Intent,
Pressure, Surface impact (HDS), шаги реализации, команды верификации, критерии успеха,
и оценку сложности.

Обозначения
- Intent: одно предложение назначения изменения
- Pressure: Bug | Feature | Debt | Ops
- Surface impact: (none) | touches: <SURFACE item(s)> [FROZEN/FLUID]

1) Plan A — Surface & Proof Lockdown (High, 1-3 days)
---------------------------------------------------
Intent: Привести Surface в програмно-проверяемое состояние и подключить базовые
Proofs к CI.
Pressure: Ops
Surface impact: touches: Healthcheck [FROZEN], Soft Reload [FROZEN]

Steps:
1. Добавить/обновить SURFACE.md (если требуется) — перечислить все публичные
   поверхности и указать Proof команды (тут уже создан SURFACE.md).
2. Включить tools/holo-verify.sh и tools/surface-lint.sh в CI (PR check). Файл
   .github/workflows/flake-check.yml уже добавлен — доработать его, чтобы на PR
   проверялся только quick-suite (unit+contract fast).
3. Внедрить PR-валидатор (action) который проверяет наличие Change Gate блокa
   в описании PR при изменениях SURFACE.md или файлов, помеченных в SURFACE.

Verification:
- CI: `nix flake check` и `./tools/holo-verify.sh` запускаются успешно on PRs
- `./tools/surface-lint.sh` возвращает OK

Success criteria:
- Все PR в main проходят quick-suite; правки SURFACE требуют Change Gate.

Risk & Rollback:
- Low risk; roll back CI workflow if false positives block merges.

2) Plan B — Test Tiering & Fast Nix-eval Unit Tests (High, 3-7 days)
----------------------------------------------------------------
Intent: Разделить тесты по уровням и добавить быструю валидацию опций и
инвариантов через nix eval.
Pressure: Debt
Surface impact: (none)

Steps:
1. Реорганизовать tests/contract -> tests/contract/unit и tests/contract/integration.
2. Написать набор Nix-eval тестов в tests/contract/unit/*.sh, примеры:
   - `nix eval --raw .#nixosConfigurations.huawei.config.pro-peer.enable` -> assert true
   - Проверить отсутствие дубликов environment.systemPackages: `rg "environment.systemPackages" -n || true` и пошаговый assert.
3. Обновить tools/holo-verify.sh чтобы по умолчанию запускал только unit-тесты,
   а интеграционные запускать опционально через флаг `--integration`.
4. Настроить CI: PRs запускают unit-tier; integration запускается по dispatch или
   на self-hosted runner.

Verification:
- `./tools/holo-verify.sh` без флагов запускает unit-tests быстро (<2m typical)
- CI PR runtime уменьшается; unit failures блокируют merge.

Success criteria:
- PR CI исполняется быстро и даёт надёжный feedback; интеграционные тесты не
  мешают повседневной разработке.

Risk & Rollback:
- Minimal; при ошибках можно временно отключить unit-suite в workflow.

3) Plan C — pro-peer Hardening (High, 2-5 days)
------------------------------------------------
Intent: Устранить классы ошибок в синхронизации ключей и коде, влияющие на
безопасность хостов.
Pressure: Ops
Surface impact: touches: Pro-peer Key Sync [FLUID]

Steps:
1. Атомарность: убедиться, что скрипт pro-peer-sync-keys.sh пишет в временный
   файл и перемещает его в /var/lib/pro-peer/authorized_keys с chmod 0600.
2. Добавить preflight: проверка GPG-расшифровки перед перезаписью; backup старого
   файла (`authorized_keys.bak.<timestamp>`).
3. Добавить systemd service exit code handling и логирование (journalctl). Добавить
   smoke-test script, который выполняет dry-run с тестовыми зашифрованными данными.

Verification:
- unit test: запуск скрипта с тестовым gpg файлём в tmp и проверка /var/lib/pro-peer content
- holo-verify integration: `bash scripts/pro-peer-sync-keys.sh --dry-run` (новый флаг)

Success criteria:
- Скрипт idempotent, атомарен, логирует операции, не приводит к временному
  потере доступа и корректно откатывает при ошибках.

Risk & Rollback:
- High-impact area; при регрессе — откатить изменения скрипта и инструкции для операторов.

4) Plan D — Emacs Soft Reload Stabilization (Medium, 2-4 weeks)
-------------------------------------------------------------
Intent: Поэтапное внедрение Soft Reload с доказуемыми invariant-ами.
Pressure: Feature
Surface impact: touches: Soft Reload [FROZEN]

Phases:
- Phase 1 (elisp-only reload): implement `pro-emacs-reload --elisp` that reloads
  load-path, reloads packages that are pure elisp, refreshes keybindings and
  minor-mode maps. Add headless ERT verifying that after reload, functions are
  available and keybindings active.
- Phase 2 (native extension detection): detect changes in native-compiled
  artifacts and require restart; provide user-facing session dump and restore
  tool (`pro-emacs-restore`).
- Phase 3 (optional): best-effort live native extension reload (risky).

Verification:
- Headless ERT suites for elisp-only reload.
- Integration test for session dump/restore (save buffer list/positions and
  restore in a clean Emacs instance).

Success criteria:
- Elisp-only reload works reliably; native-compiled changes trigger safe
  restart path with session restored.

Risk & Rollback:
- Soft reload is invasive: release behind feature flag `pro.emacs.softReload.enable`.

5) Plan E — CI maturity & reproducibility (Medium, 1-3 weeks)
-----------------------------------------------------------
Intent: Укрепить CI: кеширование dérivations, reproducibility checks, no-network mode.
Pressure: Debt
Surface impact: (none)

Steps:
1. Add cachix integration / Nix build caching in CI for faster runs.
2. Add a `no-network` CI job that denies outbound network and fails builds that
   attempt to bootstrap binaries (detect network attempts via wrapper exit codes or
   by running builds with restricted sandbox). Use `--option substituters '' ''` or CI sandboxing where possible.
3. Add status badges to README for flake-check and contract unit suite.

Verification:
- CI runs faster with cache; `no-network` job fails on bootstrap attempts.

Success criteria:
- Reproducible builds for PRs; PRs that depend on network bootstrap are flagged.

6) Plan F — Secrets & Ops playbook (High, 3-7 days)
--------------------------------------------------
Intent: Определить и задокументировать безопасный workflow для secret provisioning
Pressure: Ops
Surface impact: (none)

Steps:
1. Document recommended stack: sops/age for file encryption, GitHub Actions secrets
   for CI, and a small operator-run Ansible/just script for bootstrap.
2. Provide example files: `docs/ops/secret-provisioning.md` and example sops policy.
3. Add pre-commit hook template that blocks `*.gpg`, `*.key`, `.pem` from commit.

Verification:
- Developer can follow docs to create encrypted artifact and use `scripts/pro-peer-sync-keys.sh --dry-run` to validate.

Success criteria:
- No secrets in repo; reproducible steps for operators to provision secrets.

Оценка приоритетов (сводка)
- Immediate (1): Plan A, Plan B, Plan C, Plan F
- Short term (2): Plan E
- Mid term (3): Plan D

Как я могу помочь дальше
- Автоматически сгенерировать `docs/analyse/options.md` (полный список опций) — полезно для impact-analysis.
- Реализовать PR-валидатор Change Gate action и интегрировать в workflow.
- Начать работать по Plan B и добавить nix-eval unit tests.

Выберите вариант работы (или скажите «делай всё по порядку»):
- 1 — Сначала options.md (impact registry)
- 2 — Сначала PR-валидатор Change Gate
- 3 — Сначала unit nix-eval tests + test-tiering
- 4 — Начать сразу всё (будет разбито на мелкие коммиты)
