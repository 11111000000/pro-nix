+++
title = "Справочник"
sort_by = "weight"
template = "section.html"

[extra]
tldr = "Автогенерируемые каталоги: NixOS-опции, defcustom, клавиши, скрипты, сабмодули, тесты, CI, AI-модели и глоссарий."
+++

Каждая страница в этом разделе **сгенерирована** небольшим скриптом
в `scripts/site-extract-*.{sh,py}` из реального исходного кода.
Если источник двигается — страница двигается вместе с ним на
следующем `just site-regen`.

| Страница | Источник | Генератор |
|----------|----------|-----------|
| [NixOS-опции](reference/options.md) | 6 модулей | `tools/generate-options-md.sh` (есть) |
| [defcustom](reference/defcustom.md) | `emacs/base/modules/pro-*.el` | `scripts/site-extract-defcustom.py` |
| [Глобальные клавиши](reference/keys.md) | `emacs-keys.org` | `scripts/site-extract-keys.py` |
| [Скрипты](reference/scripts.md) | `scripts/*.sh`, `bin/*` | `scripts/site-extract-scripts.sh` |
| [Сабмодули](reference/submodules.md) | `.gitmodules` + README сабмодулей | `scripts/site-extract-submodules.py` |
| [Тесты](reference/tests.md) | `tests/**` | `scripts/site-extract-tests.py` |
| [CI-workflow](reference/ci.md) | `.github/workflows/*.yml` | `scripts/site-extract-ci.py` |
| [AI-модели](reference/ai-models.md) | `emacs/base/modules/ai-models.json` | `scripts/site-extract-ai-models.py` |
| [Глоссарий](reference/glossary.md) | ведётся вручную | `site/content/reference/glossary.md` |

Авто-генерируемые страницы помечены значком `<span class="gen-badge">auto-gen</span>`.
Они не редактируются вручную; если хотите что-то поменять — поменяйте
источник и запустите `just site-regen`.

## Почему авто-генерация

* **Drift-proof.** Если `defcustom` добавлен или удалён — справочник
  отразит это на следующей сборке, без пропущенной документации.
* **Единый источник правды.** Скрипт читает тот же `.el`-файл,
  который грузит пользователь; документация не может лгать.
* **Дёшево.** Каждый скрипт — 30-60 строк Python. Никаких внешних
  зависимостей кроме stdlib + `tomli`/`pyyaml` (опц.).

## Что **не** авто-генерируется

* **Глоссарий.** Ведётся вручную; термины проект-специфичны и
  требуют редакторского суждения.
* **Страницы хостов** (в `/hosts/`). Каждая — design-story, а не
  выжимка фактов.
* **Принципы, Рабочий процесс, Соглашения.** Это объяснения, а не
  данные.

## Регенерация сайта

```bash
just site-regen       # перегенерировать все auto-gen страницы
just site-serve       # локальный preview с live reload
just site-build       # финальный static-выход
```

`just site-regen` идемпотентен. Он не трогает страницы, которыми не
владеет. Сгенерированные файлы лежат в `site/content/reference/` и
закоммичены (чтобы `zola build` работал без Python); `git status`
после regen'а показывает ровно то, что изменилось.
