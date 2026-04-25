# Вклад в pro-nix
=================================

Кратко: перед внесением изменений прочитайте `AGENTS.md`, затем `SURFACE.md`, затем `README.md`.

Основные обязанности автора изменений
- Писать комментарии и документы на русском языке в учебном стиле: кратко формулируйте цель, инварианты и предположения.
- Один Intent — один коммит/PR. В теле коммита/PR указывайте Change Gate блок (см. шаблон ниже).
- Не добавляйте секреты в репозиторий. Если нужен секрет — используйте operator-managed encrypted artifacts (sops/age) и упомяните это в Change Gate.

Обязательные проверки перед PR
1. Убедитесь, что рабочий каталог чист: `git status --short`.
2. Запустите unit-suite: `./tools/holo-verify.sh unit`.
3. Запустите mkForce‑lint: `./tools/mkforce-lint.sh` — устраните явные проблемы или задокументируйте причину их оставления.
4. Для изменений, затрагивающих SURFACE (см. `SURFACE.md`) — обязательно заполните Change Gate в описании PR.

Change Gate — обязательный блок
Каждый PR, который меняет публичные поверхности или поведение, должен содержать в описании PR блок:

Intent: <коротко, 1 предложение>
Pressure: Bug | Feature | Debt | Ops
Surface impact: (none) | touches: <список поверхностей из SURFACE.md>
Proof: <список команд/тестов, которые проверяют изменение>

Пример Change Gate
Intent: Убрать принудительные наложения пакетов в модулях, чтобы модульные вклады были аддитивны
Pressure: Bug
Surface impact: touches: Healthcheck [FROZEN] (см. SURFACE.md)
Proof: ./tools/holo-verify.sh unit

Политики Nix (коротко)
- Модули должны добавлять пакеты через `lib.mkDefault` или возвращать списки.
- Окончательная агрегация пакетов — только в корневом `configuration.nix` (host-level); там допускается `lib.mkForce` для фиксации итогового списка.
- Избегайте обращения модулей к `config.environment.systemPackages` при формировании собственных пакетов.

Как писать безопасные патчи
- Малые изменения: один модуль — одна PR. Каждый PR должен проходить unit‑suite.
- Для безопасных, но влияющих на безопасность изменений (authorized_keys, sudo rules, samba global) — включайте canary‑план и rollback инструкции.

Рабочие команды
- Запуск unit‑suite: `./tools/holo-verify.sh unit`
- Генерация mkForce списка: `./tools/generate-mkforce-json.sh`
- Lint lib.mkForce: `./tools/mkforce-lint.sh`
- Генерация options registry (кратко): `./tools/generate-options-v2.sh`

Canary / Rollback (pro-peer example)
- Dry-run: `sudo /etc/pro-peer-canary.sh --input /tmp/test-authorized_keys.gpg --out /var/lib/pro-peer/authorized_keys`
- Apply on canary: `sudo /etc/pro-peer-sync-keys.sh --input /tmp/test-authorized_keys.gpg --out /var/lib/pro-peer/authorized_keys`
- Rollback: `sudo cp /var/lib/pro-peer/authorized_keys.bak.<timestamp> /var/lib/pro-peer/authorized_keys && sudo chown root:root /var/lib/pro-peer/authorized_keys && sudo chmod 600 /var/lib/pro-peer/authorized_keys`

Контакты и эскалация
- Для мастер-планов (многофайловые изменения, затрагивающие SURFACE) — согласуйте с владельцем репозитория. Если у вас нет владельца, откройте issue с Change Gate и обсудите план в PR.

Спасибо за аккуратные и фокусные правки — придерживайтесь HDS (Surface → Proof → Code → Verify).
