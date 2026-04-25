# Руководство для агентов (кратко)

Этот файл — минимальная справка для агентов, запускающих локальные проверки и
вносящих изменения в репозиторий pro-nix. Содержит команды для быстрой проверки
состояния репозитория и запуска тестов перед `just switch`.

Короткий чек-лист

- Убедитесь, что рабочее дерево чисто:
  - `git status --short`
  - Если есть незакоммиченные изменения: `git add -A && git commit -m "WIP: ..."`
- Запустите unit-тесты:
  - `./tools/holo-verify.sh unit`
- Запустите mkForce‑lint:
  - `./tools/mkforce-lint.sh`
- При необходимости выполните flake‑проверку:
  - `nix flake show --json .` или `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link --show-trace`

Change Gate

Перед изменением SURFACE.md или любым [FROZEN] элементом — добавьте в PR Intent,
Pressure, Surface impact и Proof (команды/тесты). См. CONTRIBUTING.md.

Операторские заметки

- Для безопасного теста синхронизации ключей используйте `scripts/pro-peer-canary.sh`
  и следуйте инструкциям в docs/ops/canary-pro-peer.md.

Формат и язык

- Все правки документации и комментариев в репозитории пишите на русском языке.

Дата: 2026-04-25
