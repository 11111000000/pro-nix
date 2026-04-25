# Change Gate

Intent: [одной строкой опишите цель изменения]

Pressure: [Bug | Feature | Debt | Ops]

Surface impact: (none) | touches: <SURFACE item(s)> [FROZEN/FLUID]

Proof: tests: <команды или файлы, подтверждающие изменение>

## Краткое описание

Опишите изменение в 2-4 пунктах. Пишите о результате и причине, а не о процессе.

## Проверки

- [ ] Я обновил `SURFACE.md`, если менялось публичное поведение.
- [ ] Я добавил или обновил Proof для `[FROZEN]` поверхностей.
- [ ] Я запустил `nix fmt`.
- [ ] Я запустил `nix flake check`.
- [ ] Я запустил `./tools/surface-lint.sh`.
- [ ] Я запустил `./tools/holo-verify.sh`.

## Migration

Заполняется только если затронут `[FROZEN]`.

- Impact: <что меняется>
- Strategy: additive_v2 | feature_toggle | break_with_window
- Window/Version: <окно или версия>
- Data/Backfill: <что нужно перенести или "n/a">
- Rollback: <безопасный откат>
- Tests:
  - Keep: <что сохраняется>
  - Add: <что добавляется>
