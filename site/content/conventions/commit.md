+++
title = "Коммиты"
template = "page.html"
weight = 1

[extra]
tldr = "Формат: тип: описание. Один коммит = одна логическая правка. Типы: nix, emacs, keys, fix, ops, site, chore."

[[extra.next]]
title = "mkForce"
url = "/conventions/mkforce/"
+++

# Коммиты

Формат: `тип: краткое описание`, одна логическая правка — один
коммит.

## Типы

| Тип | Для чего |
|-----|----------|
| `nix` | NixOS-модули, flake, host-конфиги |
| `pkg` | `system-package-sets-*` добавления/удаления |
| `emacs` | `.el`-файлы, клавиши, sites |
| `keys` | `emacs-keys.org` |
| `fix` | Багфикс на любом слое |
| `ops` | Скрипты, CI, dev-инструменты |
| `site` | Этот сайт (`site/content/`, `site/templates/`) |
| `chore` | Cleanup, refactor, docs |

## Правила

* **Один коммит = одна логическая правка.** Не смешивать слои:
  `nix: refactor pro-nfs and also add EXWM urxvt toggle` — это два
  коммита (`nix: refactor pro-nfs` + `emacs: add EXWM urxvt toggle`).

* **Краткое описание — в present tense, imperative mood.** `add`,
  `fix`, `refactor`, не `added`, `fixes`, `refactoring`. `nix: add
  pro-nfs timeout` правильно; `nix: added pro-nfs timeout` нет.

* **Тело коммита — для нетривиальных правок.** Если фикс требует
  объяснения, напишите body. Если переименование модуля — тело
  может быть пустым.

## Cleanup-коммиты

При удалении мёртвого кода — не «один большой sweep», а по
домену:

* `nix: remove X` — `flake.nix` + `configuration.nix` +
  `composition.nix` + удаляемый модуль. **Один коммит**, потому что
  промежуточное состояние сломано.
* `chore: drop unused Y` — `conf/`, тесты, артефакты,
  `.gitignore`.
* `emacs: …` — только `.el`.

Заголовок: `nix: <что>`. В теле — список всех затронутых файлов и
почему удаляется.

## Перед push

```bash
nix flake check
git status && git diff
```

`nix flake check` ловит syntax-ошибки и broken imports.
`git status && git diff` — последний шанс увидеть, что в индекс
попало что-то не то.

## Примеры хороших коммитов

```
nix: enable pro-spellcheck on huawei and vm
emacs: add pro-buffer-banner face customization
keys: add C-c a → pro-ai-open-entry
fix: cf19 dbus-regression override blocks switch
ops: just submodules-ssh — convert URLs to SSH
site: add bilingual RU/EN with language switcher
chore: drop obsolete pro-*.nix stubs
```

## Примеры плохих коммитов

```
# Слишком расплывчато
update stuff

# Смешанные слои
nix+emacs: refactor pro-foo and pro-bar

# Повелительное наклонение отсутствует
nix: added pro-foo
nix: refactoring pro-foo

# Один коммит на много фиксов
fix: a bunch of stuff
```

## Авто-генерация changelog'а

Сайт может генерировать changelog из `git log` (через
`scripts/`-которые-ещё-не-написаны, но planned). Формат коммитов
прямо определяет качество автогенерённого changelog'а.

## Где это проверяется

* `git log --oneline` — ручной просмотр.
* `scripts/agent-conventions-check.sh` — CI-ассерт последнего
  коммита на соответствие формату `тип: описание`.
* Pre-commit hook (опц.) — можно добавить, но не обязательно.
