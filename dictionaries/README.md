# Словари для проверки орфографии

Вендорённые словари, чтобы `just switch` разворачивал hunspell + ru_RU без
зависимости от конкретной версии `pkgs.hunspellDicts.ru_RU` в nixpkgs.

## Источник

| Файл     | Источник                                                                                         | Лицензия   |
|----------|--------------------------------------------------------------------------------------------------|------------|
| ru_RU.aff | https://github.com/LibreOffice/dictionaries/blob/master/ru_RU/ru_RU.aff                         | MPL-2.0    |
| ru_RU.dic | https://github.com/LibreOffice/dictionaries/blob/master/ru_RU/ru_RU.dic                         | MPL-2.0    |

Дата загрузки: 2026-06-06.

Словарь содержит ~146 000 базовых словоформ и расширения для
склонений/спряжений; используется `pro-hunspell` (см. `modules/pro-spellcheck.nix`).

## Обновление

```sh
cd dictionaries/hunspell
curl -fsSLO https://raw.githubusercontent.com/LibreOffice/dictionaries/master/ru_RU/ru_RU.aff
curl -fsSLO https://raw.githubusercontent.com/LibreOffice/dictionaries/master/ru_RU/ru_RU.dic
```

Затем зафиксировать изменения в коммите `chore: refresh ru_RU hunspell dict`.

## Дополнительные словари

Английский (`en_US`) подтягивается из `pkgs.hunspellDicts.en_US` при
`pro.spellcheck.secondaryDicts = [ "en_US" ];` — без вендоринга в репу.
