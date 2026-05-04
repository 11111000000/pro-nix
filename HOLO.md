HOLO — Holographic Manifest

Stage: RealityCheck

Purpose: короткий манифест репозитория: инварианты, публичные решения и правила изменения кода. HOLO служит справочником для агентов и мейнтейнеров — какие свойства гарантируются и как их проверять.

Инварианты (INV-*)

1. INV-Core-IO-Boundary
   Ядро логики не содержит побочных эффектов; все эффекты инкапсулируются в адаптерах (Nix-модули, скрипты, Emacs-адаптеры).

2. INV-Determinism
   Сборки и функции при тех же входных данных дают детерминированный результат. Изменения, влияющие на воспроизводимость, требуют Proof.

3. INV-Canonical-Roundtrip
   FROZEN-артефакты и контракты поддерживают roundtrip (encode ∘ decode = id) там, где это применимо.

4. INV-Surface-First
   Любые изменения публичной поверхности начинаются с обновления SURFACE.md и формулировки Proof до изменения кода.

5. INV-Traceability
   Каждое изменение сопровождается Change Gate: Intent, Pressure (Bug/Feature/Debt/Ops), Surface impact и Proof. PR должен ссылаться на соответствующие тесты/скрипты.

6. INV-Docs-Russian
   Документация, комментарии и docstring — на русском языке.

7. INV-Test-Coverage-for-Surface
   Каждая запись в SURFACE.md имеет Proof — однозначную команду/скрипт/тест, который можно запустить локально/в CI.

8. INV-Deterministic-Flake-Outputs
   Flake outputs, используемые в Proof или CI, должны быть buildable локально. Изменения, затрагивающие outputs, требуют дополнительной валидации в CI.

9. INV-OneFile-OneResponsibility
   Один файл — одна ответственность. Если файл выходит за границы, предлагается декомпозиция через Change Gate.

10. INV-No-Secrets
    В репозитории не хранить секреты; любые инструкции по секретам должны указывать на безопасное внешнее хранилище.

11. INV-Emacs-Package-Precedence
    В pro-Emacs вручную установленные пакеты и runtime package.el имеют приоритет над Nix-provided; архивы `gnu`, `nongnu`, `melpa` подключаются при старте, `package-refresh-contents` выполняется только по необходимости.


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
