**Диалектический анализ и план действий — упущенные приоритеты UI/UX Emacs (pro-nix)**

Коротко: для каждого приоритета даю тезис → антитезис → синтез и минимальный план действий (Surface → Proof → Code → Verify), оценки усилий и риски. Все изменения должны следовать Change Gate (HOLO.md / SURFACE.md).

1) Soft Reload (операционная безопасность) — (тезис / антитезис / синтез)
 - Тезис: Soft Reload необходим для быстрой итерации UI без полной перезагрузки системы.
 - Антитезис: Нативные модули (native-compile, C-extensions) ломают ин-процесс обновления; неконтролируемый reload повреждает сессии.
 - Синтез: Внедряем опциональный, безопасный soft-reload с детектированием изменений native-битов и автоматическим прогулом через контролируемый restart с дампом сессии.

 План (минимум):
 - Surface: уже [FROZEN] в HOLO.md — обновить Migration (сделано).
 - Proof: headless ERT `tests/contract/test-soft-reload.el` (имитировать site-lisp path change, assert session snapshot/restore).
 - Code: команда `pro-emacs-reload` (best-effort reload) + `pro-emacs-restart-safe` (snapshot → restart → restore).
 - Verify: ERT + manual scenario (upgrade native package → controlled restart).
 Оценка: 3–10d (спец. реализация restore требует аккуратности).
 Риски: потеря внешних процессов (vterm, LSP). Смягчение: ограниченный контракт восстановления и пользовательский откат.

2) GUI smoke testing (CI) — надежность
 - Тезис: headless ERT не покрывает GUI (child-frame, posframe, fonts), регрессии проходят незамеченными.
 - Антитезис: headful тесты сложны и плохо детерминированы, увеличивают CI-время.
 - Синтез: добавить узконаправленный GUI-smoke job в CI через Nix+Xvfb, проверяющий API-уровень (не пиксели).

 План:
 - Surface: SURFACE.md add `Emacs GUI UX Layer` (сделано).
 - Proof: `tests/gui/gui-smoke.el` (создан), CI workflow `.github/workflows/gui-smoke.yml` (создан), gated по путям.
 - Code: улучшать тест по результатам ранних прогонов (добавить tolerant checks и артефакты логов).
 - Verify: CI green; автозапуск на PR с изменениями emacs/**.
 Оценка: 2–4d
 Риски: runner differences; смягчение: gate по путям и tolerant assertions.

3) Accessibility и контрастность — общее качество
 - Тезис: отсутствие политика контраста и масштабирования приводит к плохой читабельности у части пользователей.
 - Антитезис: строгие требования нарушают кастом пользовательских тем.
 - Синтез: определить рекомендуемые профили (default, high-contrast, large-text), тестировать дефолтный профиль и не ломать пользовательские.

 План:
 - Surface: добавить пункт Accessibility в SURFACE.md (рекомендовано).
 - Proof: ERT `tests/contract/test-theme-contrast.el` (создан) — проверка default face contrast.
 - Code: expose настройку `pro.emacs.ui.accessibility.profile` (дизайн), добавить preset themes.
 - Verify: ERT + manual visual audits.
 Оценка: 1–3d

4) IME / platform input parity (Wayland / macOS / Windows)
 - Тезис: IME играет ключевую роль для немонолатинских пользователей; баги ломают ввод.
 - Антитезис: полноавтоматическое тестирование IME трудно, платформ-зависимо.
 - Синтез: формализовать matrix платформ, document known caveats, добавить ручные тест-кейсы; автоматизировать где возможно.

 План:
 - Surface: добавление заметки в SURFACE.md (Fonts & IME behaviour).
 - Proof: manual test checklists (docs/platform-input.md) + CI smoke where possible (Windows runners / macOS not free on GH Actions).
 - Code: platform adapters и guards (display-graphic-p и platform-specific hooks).
 - Verify: manual platform tests; community contributors for coverage.
 Оценка: 1–5d (документирование) + platform fixes по необходимости.

5) Keybinding discoverability и conflict resolution
 - Тезис: предложенные ключи (modules) уже собираются, но пользователю непонятно как принимать/отклонять; конфликты тихо накапливаются.
 - Антитезис: автоматическая смена биндингов раздражает и непредсказуема.
 - Синтез: интерактивный opt-in flow + командная palette для разрешения конфликтов; сохранять решения и экспортировать предложения для ревью.

 План:
 - Surface: document behavior in SURFACE.md (OnboardingWizard touches keys discovery).
 - Proof: ERT test for merge logic `tests/contract/test-keys-merge.el` (skeleton).
 - Code: implement `pro/keys-import-suggestions`, `pro-emacs-keys-resolve` interactive UI (skeleton); register suggested keys safely (done defensive changes).
 - Verify: ERT + manual UX (onboarding flow).
 Оценка: 2–5d

6) Onboarding / first-run flow
 - Тезис: новый пользователь должен быстро понять defaults and opt-ins.
 - Антитезис: intrusive wizards annoy experienced users.
 - Синтез: opt-in wizard shown by default on first-run with skip and re-run commands; show summary of key suggestions and package auto-install consent.

 План:
 - Surface: OnboardingWizard already added (SURFACE.md).
 - Proof: headless non-interactive ERT ensuring first-run flag is respected.
 - Code: `pro-emacs-onboarding-run` + minimal UI prompts; add docs.
 - Verify: headless ERT + manual run.
 Оценка: 1–3d

7) Startup metrics & lazy-loading policy
 - Тезис: без эмпирики любые оптимизации startup — догадки.
 - Антитезис: сбор метрик добавляет шум и кодоремонт.
 - Синтез: небольшой локальный metrics collector (time-to-first-input, module load timings), хранение в `~/.local/state/pro-emacs/metrics.json`.

 План:
 - Proof/Code: `emacs/base/modules/startup-metrics.el` (создан), script to dump/format.
 - Verify: run metric script on devshell and CI (optional).
 Оценка: 0.5–1.5d

8) Session management и workspace restore
 - Тезис: пользователи ожидают безопасной реставрации окон/буферов после restart.
 - Антитезис: попытка восстановить всё (процессы, сокеты) невозможна.
 - Синтез: ввести контракт восстановления (что гарантируется), реализовать snapshot/restore для встраиваемых сущностей (buffers, window-state), логировать несопоставимые элементы.

 План:
 - Surface: add `SessionRestore` notes to SURFACE.md.
 - Proof: ERT `tests/contract/test-session-restore.el` (skeleton) verifying basic items.
 - Code: `emacs/base/modules/session-serializer.el` (skeleton) to write snapshot and restore.
 - Verify: ERT + manual scenario involving native package change + controlled restart.
 Оценка: 2–5d

9) TTY/SSH parity & graceful fallbacks
 - Тезис: many users run Emacs over SSH; UI must gracefully degrade.
 - Антитезис: parity impossible for features like child-frames/icons.
 - Синтез: formalize fallback policy and ensure terminal-friendly codepaths via `ui-tty.el` and corfu-terminal.

 План:
 - Proof: `tests/contract/test-tty.el` (emacs -nw smoke) to ensure no startup errors and functional defaults.
 - Code: audit `emacs/base/modules/ui-tty.el` and add terminal presets where missing.
 - Verify: run under varied $TERM values in CI / local tests.
 Оценка: 0.5–1.5d

10) Fonts & icon delivery via Nix
 - Тезис: icons improve UX but depend on fonts being installed by Nix.
 - Антитезис: installing fonts system-wide may be undesirable; need graceful fallback.
 - Синтез: declare fonts in modules/system-packages and runtime checker that logs and falls back to text icons (pro-emacs-check-fonts.el created).

 План:
 - Proof: gui-smoke test checks font availability (done basic); add test that kind-icon falls back when font missing.
 - Code: Nix packaging review to ensure fonts included when GUI layer enabled.
 - Verify: CI smoke + manual verification.
 Оценка: 0.5–2d

11) Auto-install packages & consent (privacy)
 - Тезис: automatic package install is convenient (PRO_PACKAGES_AUTO_INSTALL) but surprising and network-dependent.
 - Антитезис: forcing explicit install interrupts UX.
 - Синтез: require opt-in in onboarding wizard and provide an explicit variable `pro.emacs.packages.autoInstall` with safe default OFF in sensitive contexts (CI/headless).

 План:
 - Surface: document in SURFACE.md / onboarding.
 - Proof: ERT check that env var respected in non-interactive runs.
 - Code: wire onboarding step and config flag.
 - Verify: manual + CI.
 Оценка: 0.5–1d

Приоритеты (порядок исполнения)
 1) Soft Reload migration & tests (FROZEN) — безопасность (High)
 2) GUI smoke CI + fonts checks — защищает от регрессий (High)
 3) Accessibility checks (theme contrast) — качество UX (High)
 4) Session snapshot/restore (Medium)
 5) Keys discoverability + onboarding wiring (Medium)
 6) Startup metrics + lazy-load instrumentation (Medium)
 7) IME / platform parity (Medium, ongoing)
 8) TTY fallbacks and LSP diagnostics polish (Low→Medium)
 9) Auto-install consent (Low→Medium)

Быстрая тактика (минимально-инвазивный путь)
 - Шаг А (1–2 дней): добавить/выровнять Surface записи и базовые Proof тесты (theme contrast, gui-smoke skeleton, startup metrics) — выполнено частично.
 - Шаг B (2–4 дней): CI gui-smoke развернуть, собрать первые данные, отловить flaky.
 - Шаг C (1–2 спринта): Soft Reload implementation + session-serializer и ERTs.
 - Параллельно: keys-resolver и onboarding прототип (interactive), IME doc + manual testkits.

Change Gate и HDS соответствие
 - Для каждого шага: добавить Intent/Pressure/SurfaceImpact/Proof в PR (PULL_REQUEST_TEMPLATE.md обновлён) и ссылку в SURFACE.md.
 - Touching [FROZEN] требует Migration и Proof до включения по умолчанию (Soft Reload).

Вопросы/решения
 - Хотите, чтобы я: 1) автоматом создал skeletonы для session-serializer и keys-resolver в репозитории, или 2) сначала подготовил PR с ERT и CI только? Ответьте кратко — начну реализацию.
