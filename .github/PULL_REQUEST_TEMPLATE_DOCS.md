Intent: Обновить HOLO.md и SURFACE.md до полного состояния, внедрить стиль‑гайд для "литературных" комментариев на русском и начать итеративный рефактор документации.

Pressure: Debt

Surface impact:
- touches: HOLO.md [FROZEN], SURFACE.md [FROZEN], docs/STYLE-GUIDE-RU.md

Proof:
- ./tools/surface-lint.sh
- ./tools/holo-verify.sh
- ./tools/docs-link-check.sh
- nix flake check

Migration: none (только документация). Если формат SURFACE.md изменится существенно — добавить миграционный скрипт.

Описание изменений:
- Добавлены: обновлённые HOLO.md (инварианты), расширённый SURFACE.md, docs/STYLE-GUIDE-RU.md.
- Добавлен CSV аудит файлов, требующих литературных шапок: docs/audit_comments.csv.

Check list (manual):
- [ ] Запуск ./tools/surface-lint.sh проходит без критических ошибок
- [ ] Запуск ./tools/holo-verify.sh проходит
- [ ] nix flake check проходит
- [ ] HEAD не содержит runtime изменений
