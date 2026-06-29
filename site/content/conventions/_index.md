+++
title = "Соглашения"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Governance: формат коммитов, mkForce vs mkDefault, Change-Gate для PR, детекторы мёртвого кода, анти-паттерны."
+++

В репозитории нет формального RFC-процесса. Есть **соглашения**,
которым должны следовать все — человек или агент. Каждое короткое,
у него есть причина, и за ним как минимум один
`tests/contract/*`-чек.

См. под-страницы ниже.

## Под-страницы

* [Коммиты](conventions/commit.md) — формат `тип: описание`,
  список типов.
* [mkForce](conventions/mkforce.md) — три приоритета NixOS module
  system и когда какой использовать.
* [Change-Gate](conventions/change-gate.md) — формат PR body с
  Intent/Pressure/Surface/Proof.
* [Мёртвый код](conventions/dead-code.md) — детекторы и ритуал
  удаления.
* [Анти-паттерны](conventions/anti-patterns.md) — то, что в коде
  есть, но не стоит добавлять самому.

## Общий обзор (кратко)

| Соглашение | Суть | Где проверить |
|------------|------|---------------|
| Формат коммитов | `тип: краткое описание`, одна логическая правка | `git log --oneline -10` |
| Один коммит = одно изменение | Не смешивать `nix:` и `emacs:` в одном коммите | То же |
| `lib.mkDefault` НЕ для обязательных пакетов | Иначе другой модуль молча их перезапишет | `tools/mkforce-lint.sh` |
| Один headscale control plane | На всех ноутбуках `lib.mkForce false` | `rg "headscale" hosts/*/configuration.nix` |
| Шапка `modules/*.nix` | 4 секции: Назначение / Цель / Контракт / Proof | `tools/surface-lint.sh --check-style` |
| `git+file://...?submodules=1` | Не `path:` и не `.` | `rg "path:\|\\.\\." justfile flake.nix` |
| Нет `global-set-key` в модулях | Только `emacs-keys.org` | `scripts/helper-lint-keys.sh` |
| Buffer-local zoom | `text-scale-*`, не `set-face-attribute` | (конвенция; см. AGENTS.md §7) |
| Нет `nixos-rebuild switch` в CI | Только `eval` / `build` / `test` | `.github/workflows/*.yml` |
| `~/.authinfo` для AI-ключей | Не коммитить, не в `~/.bash_history` | `~/.gitignore` |

## Куда смотреть

* `AGENTS.md` — полный свод правил.
* `tools/holo-verify.sh` — оркестратор тестов.
* `tools/surface-lint.sh` — секции шапки + наличие кириллицы.
* `tools/mkforce-lint.sh` — счётчики `lib.mkForce` и `systemPackages`.
* `tools/docs-link-check.sh` — сломанные внутренние ссылки.
* `tests/contract/*` — per-convention ассерты.
* `tests/contract/unit/*` — короткие shell-скрипты.
