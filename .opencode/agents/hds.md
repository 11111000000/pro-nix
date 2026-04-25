# HDS для агентов

## Назначение
- Этот файл фиксирует минимальный порядок HDS: Surface → Proof → Code → Verify.

## Change Gate
- Intent: одна цель изменения.
- Pressure: `Bug`, `Feature`, `Debt`, `Ops`.
- Surface impact: какие элементы `SURFACE.md` затронуты и их стабильность.
- Proof: тесты, команды или CI-job.
- Migration: обязательно для `FROZEN`.

## Правило поверхности
- Если меняется внешнее поведение, сначала обновить `SURFACE.md`.
- Для `FROZEN` Proof должен существовать до кода или вместе с ним.

## Правило отказа
- Если Gate отсутствует для `FROZEN`, агент не продолжает работу.

## Проверки
- `./tools/surface-lint.sh`
- `./tools/holo-verify.sh`
