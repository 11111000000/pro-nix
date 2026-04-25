Analysis artifacts
==================

Этот каталог содержит машинно-ориентированный анализ репозитория pro-nix,
подготовленный автоматическим агентом 2026-04-25. Файлы:

- analyse/00-overview.md — goals and method
- analyse/01-modules.md — modules catalog
- analyse/02-tests.md — tests and proofs
- analyse/03-analysis.md — dialectical analysis
- analyse/04-recommendations.md — prioritized improvements and steps
- analyse/05-enumerated-functions.md — scripts and entrypoints list

Используйте `tools/holo-verify.sh` для запуска контрактных тестов, указанных в
`HOLO.md`. Используйте `tools/surface-lint.sh`, чтобы проверить наличие
`SURFACE.md` и ссылок на Proof.
