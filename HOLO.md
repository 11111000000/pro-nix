HOLO — Holographic Manifest

Stage: RealityCheck

Purpose: короткий манифест репозитория: инварианты, публичные решения и правила изменения кода. HOLO служит справочником для агентов и мейнтейнеров — какие свойства гарантируются и как их проверять.


Инварианты (INV-*)

Общая часть (процессные и общесистемные инварианты)

1. INV-Core-IO-Boundary
   Ядро логики не содержит побочных эффектов; все эффекты инкапсулируются в адаптерах (Nix-модули, скрипты, Emacs-адаптеры). Proof: code review + unit tests.

2. INV-Determinism
   Сборки и функции при тех же входных данных дают детерминированный результат. Изменения, влияющие на воспроизводимость, требуют Proof (nix build / nix eval). Proof: `nix build`, `nix eval`.

3. INV-Surface-First
   Любые изменения публичной поверхности начинаются с обновления SURFACE.md и формулировки Proof до изменения кода. Proof: `.github/actions/check-change-gate/action.sh` + review policy.

4. INV-Traceability
   Каждое изменение сопровождается Change Gate: Intent, Pressure (Bug/Feature/Debt/Ops), Surface impact и Proof. PR должен ссылаться на соответствующие тесты/скрипты. Proof: PR template + CI check.

5. INV-Docs-Russian
   Документация, комментарии и docstring — на русском языке. Proof: surface-lint/docs lint.

6. INV-Test-Coverage-for-Surface
   Каждая запись в SURFACE.md имеет Proof — однозначную команду/скрипт/тест, который можно запустить локально/в CI. Proof: `./tools/surface-lint.sh`.

7. INV-Deterministic-Flake-Outputs
   Flake outputs, используемые в Proof или CI, должны быть buildable локально. Proof: `nix flake check` + selective build.

8. INV-OneFile-OneResponsibility
   Один файл — одна ответственность. Если файл выходит за границы, предлагается декомпозиция через Change Gate. Proof: review + static checks.

9. INV-No-Secrets
   В репозитории не хранить секреты; любые инструкции по секретам указывают на approved tools (sops/age/Vault) и на процедуру ротации. Proof: grep checks + secrets-scan in CI.

10. INV-Verification-Automation
    Proof‑скрипты (`./tools/holo-verify.sh`, `./tools/surface-lint.sh`) покрывают все FROZEN поверхности в fast/full режимах и запускаются в CI. Proof: CI jobs present and passing.


NixOS‑ориентированные инварианты (конфигурационные, проверяемые)

11. INV-Module-Composition
    Все модули добавляют опции и пакеты с использованием `lib.mkDefault`/`lib.mkIf` для композиции; `lib.mkForce` допускается только в host-level finalization. Proof: `tools/generate-options-md.sh`, `tools/mkforce-lint.sh`.

12. INV-No-Recursive-SystemPackages
    `environment.systemPackages` не должен ссылаться на `config.environment.systemPackages` в модулях (избегать рекурсии). Proof: `tests/contract/unit/09-system-packages-eval.sh`, static grep tests.

13. INV-Host-Override-Last
    Host-конфигурации могут переопределять значения, но базовые модули остаются additive. Proof: `nix eval .#nixosConfigurations.<host>.config` checks.

14. INV-Boot-Policy-Explicit
    Параметры загрузчика и ядра (boot.loader, boot.kernelPackages, sysctl) фиксируются явно в конфигурации. Proof: `nix eval --json .#nixosConfigurations.<host>.boot.loader`.

15. INV-Firewall-Is-Additive
    Политики firewall добавляют правила (concat/ lib.mkDefault), не перезаписывая глобальные списки. Proof: review + `nix eval` checks in modules/pro-peer.nix and configuration.nix.

16. INV-Tor-Verify-Compatible
    Tor конфигурирование избегает runtime `Include` директив, чтобы `tor --verify-config` проходил для декларативных конфигов. Proof: `tests/contract/tor-01.sh` and `./scripts/ops-ensure-tor.sh`.

17. INV-SSH-Keys-Runtime
    authorized_keys управляются runtime (e.g., `/var/lib/pro-peer/authorized_keys`) — не хранить динамические ключи в eval-time sources. Proof: `modules/pro-peer.nix` + `scripts/ops-pro-peer-sync-keys.sh` + unit tests.

18. INV-Systemd-Units-Verifiable
    ExecStart в unit-файлах должен ссылаться на конкретные store‑пути или на простые wrappers, чтобы `systemd-analyze verify` проходил. Proof: `tests/contract/validate-units.sh`, `scripts/verify-units.sh`.

19. INV-Service-Resource-Limits
    Долговременные/операционные сервисы имеют ограничение ресурсов (CPUQuota/Mem/oomd) по умолчанию или через slice. Proof: `nix eval` checks + `systemd-analyze verify`.

20. INV-SystemPackages-Evaluates-Standalone
    `system-packages.nix` вычисляется отдельно и возвращает список пакетов (не thunk). Proof: `tests/contract/unit/09-system-packages-eval.sh`.

21. INV-Emacs-State-Isolated
    Emacs state и cache находятся в XDG-пути (`~/.local/state/pro-emacs`, `~/.cache/pro-emacs`) и не попадают в `load-path`. Proof: `emacs/base/modules/pro-history.el` + `emacs/base/tests/test-history.el`.

22. INV-Emacs-Package-Availability
    Пакеты, объявленные Nix-ом, должны быть доступны на `load-path`; interactive installs допускаются только по allowlist. Proof: `emacs/base/modules/pro-packages.el` + headless ERT.

23. INV-Opencode-Isolated
    Opencode/runtime сервисы запускаются в выделенных slices и имеют reproducible build entrypoints. Proof: `nixos/modules/opencode.nix`, `tests/contract/unit/04-opencode-options.sh`.

24. INV-Activation-Preflight
    Перед `nixos-rebuild switch`/`just switch` выполняются preflight проверки: вычислимость профиля пакетов, unit verify, quick smoke tests. Proof: `scripts/helper-check-nixos-build.sh`, `tests/contract/test_live_activation_smoke.sh`.

25. INV-Host-Matrix-Coverage
    Для поддерживаемых хостов (huawei, cf19, vm, ...) определён набор Proofs и smoke tests; изменения в общих модулях требуют проверки в host matrix. Proof: `tests/vm/*`, host-specific `nix build` checks.

26. INV-StateVersion-IsIntentional
    `system.stateVersion` фиксируется и изменение требует migration plan. Proof: review + CI check for stateVersion drift.

27. INV-Generated-Files-Declarative
    Все /etc/файлы, tmpfiles rules и wrappers должны задаваться декларативно в Nix (environment.etc / systemd.tmpfiles.rules). Proof: `nix eval` and `tests/contract/validate-units.sh`.

28. INV-Options-Versioning
    Публичные Nix module options имеют версионирование и migration notes when changed. Proof: `tools/generate-options-md.sh` and CHANGELOG/UPGRADING notes.




Decisions

- [Draft] Emacs profile
  Provide a default portable Emacs + EXWM profile. Exit criteria: migration plan and headless ERT Proof.

- [FROZEN] Soft Reload
  Safe opt-in механизм обновления UI/модулей Emacs без полного перезапуска. Proof: headless ERT suite listed in SURFACE.md.
  Migration notes: при изменениях native-compiled компонентов требуется контролируемый рестарт с сохранением сессии.

- [Draft] Pro-peer Discovery & Key Sync
  Operational surface for distributing authorized_keys between trusted hosts. Pressure: Ops. Exit: documented migration and smoke tests.

- [Draft] LLM Research Surface
  Provide reproducible notebook-based environment and entrypoints (llm-lab). Exit: `llm-lab` on PATH and proof script coverage.


Proofs / Verification Commands (use in Change Gate)

- `./tools/surface-lint.sh`
- `./tools/holo-verify.sh`
- `nix flake check`
- `tests/contract/test_surface_health.spec`

Notes

- Не вносите изменения в FROZEN-поверхности без полного Change Gate и Proof. Для документационных правок в SURFACE/HOLO достаточно Intent/Pressure=Debt и Proof: `./tools/surface-lint.sh`.
