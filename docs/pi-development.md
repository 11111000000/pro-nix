# `pi`: запуск из исходников

Кратко
------
В этой конфигурации глобальная команда `pi` не ставит релизный бинарник. Она
вызывает локальный checkout `~/Code/pi` и запускает его из исходников.

Подготовка
----------
- Положите исходники `pi` в `~/Code/pi` или задайте `PI_SOURCE_DIR`.
- В checkout должны быть `pi-test.sh` и `packages/coding-agent/`.
- Для первичной установки зависимостей нужен `npm`.

Запуск
------
- `pi` — запускает `~/Code/pi/pi-test.sh`.
- `pi --help` — показывает краткую справку по wrapper-у.
- `pi-dev` — запускает `npm --prefix "$PI_SOURCE_DIR/packages/coding-agent" run dev`.

Поведение wrapper-ов
--------------------
- Если в checkout нет `node_modules/.bin/tsx`, wrapper `pi` выполняет
  `npm install` в `PI_SOURCE_DIR`.
- Если в checkout нет `node_modules/.bin/tsgo`, wrapper `pi-dev` выполняет
  `npm install` в `PI_SOURCE_DIR`.
- Переменная `PI_SOURCE_DIR` имеет приоритет над значением по умолчанию
  `$HOME/Code/pi`.

Ожидаемый цикл разработки
-------------------------
1. Обновите checkout `pi`.
2. Запустите `pi-dev` для режима разработки.
3. Запускайте `pi` для проверки сценария из `pi-test.sh`.
4. При изменении кода в `pi` повторяйте шаги без переустановки системы.

Проверка
--------
- Контракт запуска wrapper-ов покрыт `tests/contract/test_runtime_packages.sh`.
