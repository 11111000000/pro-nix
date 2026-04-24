Диалектическая критика и улучшённые планы
========================================

Цель: переработать предыдущие планы (docs/plabns/optimal-improvements.md) через
диалектику — выявить противоречия, убрать ненужное, усилить важное и дать
конкретную последовательность действий, которая минимизирует риски и принесёт
максимальную практическую пользу в короткие сроки.

Метод: для каждого плана применена схема Thesis / Antithesis / Synthesis — это
помогает отделить риторические цели от конкретных задач и выбрать те, которые
дают наибольшую ценность при минимальных затратах.

Ключевой вывод (one-liner): фокусируемся на трёх вещах сначала — (1) автоматическая
проверка Change Gate + SURFACE→Proof соответствие в CI, (2) быстрые Nix-eval
юнит-тесты и tiering тестов, (3) крепкая атомарная синхронизация ключей
(pro-peer). Всё остальное — вторично и внедряется после этих гарантий.

Почему именно эти три?
- Change Gate в CI обеспечивает гарантию следования HDS — без этого политика
  остаётся декларацией. Это минимальный институциональный контроль.
- Быстрые Nix-eval тесты резко повышают скорость обратной связи и уменьшают
  риск регресса при правках конфигурации (низкий геморрой, высокий ROI).
- Pro-peer затрагивает безопасность хостов — ошибки здесь имеют высокий риск
  и должны быть укреплены оперативно.

Универсальные улучшения к подходу (метапризы)
- Каждый план сопровождается Change Gate блоком (Intent, Pressure, Surface impact, Proof).
- Делать маленькие итеративные PR: Surface → Proof → Code → Verify.
- Автоматизировать обнаружение влияния: при изменении файлов modules/* или SURFACE.md
  CI должен запускать impact-analysis (options.md generation) и требовать Change Gate.

Переработанные планы (консолидировано)

Wave 0 — Immediate Safety (0.5–3 days)
-------------------------------------
Goal: быстрые улучшения, которые резко повышают безопасность процесса внесения правок.

Plan 0.1 — Enforce Change Gate in CI
  Thesis: PR-level Change Gate enforcement makes HDS реальностью.
  Antithesis: наложение строгих требований может блокировать работу, если validator ложно срабатывает.
  Synthesis: внедрить non-blocking initial check (warning), затем перевод в blocking после 48 часов и 2-3 мелких PR с исправлениями.

  Change Gate:
  - Intent: Автоматически проверять, что PR, меняющий SURFACE или модули, содержит Change Gate блок в описании.
  - Pressure: Ops
  - Surface impact: touches: SURFACE.md (FROZEN items)
  - Proof: CI job `ci/check-change-gate` (script checks PR body for Intent/Pressure/Surface/Proof).

  Steps:
  1. Добавить простой GitHub Action `ci/check-change-gate` (bash) в .github/workflows. Action делает regex-валидатор PR body.
  2. Сначала — non-blocking (comment with guidance). Через 48 часов — перевести в blocking.
  3. В README/CONTRIBUTING добавить шаблон Change Gate (пример).

  Verification: merged PR без Change Gate будет помечен (и затем заблокирован после переходного периода).

  Est: 0.5–1 day to add validator, 2 days to iterate and flip to blocking.

Plan 0.2 — Fast Test Tiering & Nix-eval unit tests
  Thesis: Быстрая обратная связь снижает время исправления ошибок.
  Antithesis: Написание тестов требует времени и поддержания; некоторые проверки хрупки.
  Synthesis: начать с маленького набора проверок (types/defaults, systemPackages duplication) и интегрировать в CI; расширять итеративно.

  Change Gate:
  - Intent: Создать unit-tier тестов на базе `nix eval` и запустить их в PR CI.
  - Pressure: Debt
  - Surface impact: (none)
  - Proof: `tests/contract/unit/*.sh` и `ci/run-unit-tests` job.

  Steps:
  1. Реорганизовать tests/contract -> tests/contract/unit + integration.
  2. Добавить 5–10 базовых nix-eval проверок: опции pro-peer/pro.emacs defaults, наличие pro-peer.keysGpgPath, отсутствие многократных environment.systemPackages определения.
  3. Update tools/holo-verify.sh to run only unit by default; add `--integration`.
  4. Wire unit job into CI workflow (fast, < 2–3 min typical).

  Verification: PRs показывают unit-test results quickly; flaky tests moved to integration.

  Est: 1–3 days initial (get 10 checks), ongoing maintenance small.

Plan 0.3 — Pro-peer atomicity & safety
  Thesis: key sync is high-risk; must be atomic and logged.
  Antithesis: changing sync logic risks outages; operators depend on current behaviour.
  Synthesis: implement safe atomic write + dry-run + backups + strict permission checks with opt-in rollout.

  Change Gate:
  - Intent: Сделать pro-peer sync atomic, idempotent и с dry-run mode.
  - Pressure: Ops
  - Surface impact: touches: Pro-peer Key Sync [FLUID]
  - Proof: unit test + `bash scripts/pro-peer-sync-keys.sh --dry-run` + systemd timer smoke.

  Steps:
  1. Modify script to write to temp file, validate GPG decryption output, chmod 0600, mv to final path; create backup before overwrite.
  2. Add `--dry-run` and `--backup` flags; add clear logging to stdout and journal via systemd.
  3. Add unit test using temporary directory to validate atomic behaviour.
  4. Deploy behind pro-peer.enableKeySync (feature gate) — default enabled but operator can disable.

  Verification: run dry-run with test gpg file; inspect backup file and permissions.

  Est: 1–3 days.

Wave 1 — Reliability & Reproducibility (1–2 weeks)
-------------------------------------------------
Goal: обеспечить воспроизводимость сборок и адекватную CI-платформу.

Plan 1.1 — No-network reproducibility job + cachix
  - Intent: CI must flag PRs that rely on network bootstraps.
  - Pressure: Debt
  - Surface impact: (none)
  - Proof: `ci/no-network` job that runs builds with network disabled.

  Steps:
  1. Add cachix usage to speed up CI.
  2. Add no-network job: set environment to block HTTP/HTTPS and run `nix build` or run builds with `--option substituters '' --option trusted-public-keys ''` so no external substituters used.
  3. Fail PRs that require network bootstrap.

Plan 1.2 — Integration tier orchestration
  - Move heavy tests (systemd-nspawn, Xvfb) into a scheduled or manual workflow and document runner requirements.

Wave 2 — Feature hardening & UX (2–6 weeks)
-------------------------------------------------
Goal: Soft Reload rollout, ops playbooks, options registry, and incremental hardening.

Plan 2.1 — Soft Reload staged rollout (elisp-only first)
  - Break into small deliverables: implement elisp reload + tests, then native detection + restart path.

Plan 2.2 — Options registry (impact analysis)
  - Generate docs/analyse/options.md listing defined options and origin files. Use this registry in CI impact analysis when modules change.

Plan 2.3 — Secrets & Ops playbook
  - Document sops/age workflow, CI secret injection, key rotation steps, and add pre-commit guard.

Execution order (concrete and minimal risk)
1. Wave0.Plan0.1 (Change Gate validator, non-blocking) — immediate.
2. Wave0.Plan0.2 (unit tests + tiering) — immediate parallel.
3. Wave0.Plan0.3 (pro-peer atomicity) — immediate and merged with tests.
4. Wave1.Plan1.1 (no-network + cachix) — after 0.1/0.2 stable.
5. Wave2.Plan2.2 (options registry) — run after initial CI gating to enable impact analysis.

Metrics to watch
- PR lead time (target: unit CI + flake check < 5 minutes)
- Number of PRs missing Change Gate (target: 0 after enforcement)
- Number of incidents related to pro-peer key sync (target: 0 after hardening)
- Percentage of PRs passing no-network job (target: >95%)

Risk management and rollback rules
- For each change touching FROZEN SURFACE: require migration block in PR and make new tests that demonstrate backward compatibility.
- When a CI validator is introduced, start non-blocking; monitor false positives for 48–72 hours and then flip to blocking.
- Keep all changes reversible: feature gates and ability to disable services via host local.nix must remain.

Заключение
-----------
Я упростил план до набора конкретных, приоритетных волн и дал четкие шаги и критерии.
Если вы согласны, я начну с Wave0: реализую Change Gate validator (non-blocking) +
unit-test tier + голую atomic pro-peer patch и соответствующие unit tests. Поставьте
"Сделать Wave0" или выберите другой стартовый пункт.
