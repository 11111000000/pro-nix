# План работ: устранение регрессии runtime и стабилизация live switch

Цель
-----
Устранить регрессию пропажи рантайм‑утилит и избежать отказа live activation (Rejected send message) при `nixos-rebuild switch`. Рефакторинг configuration.nix на модули для простоты и меньшего риска в будущем.

Шаги (по приоритету)
--------------------
1) Минимальный быстрый фикс (низкий риск)
  - Явно зафиксировать набор рантайм‑пакетов в top‑level: bashInteractive, openssh, coreutils, procps, dbus.
  - Запустить сборку и smoke‑тесты.

2) Исправление порядка polkit/dbus (средний риск, но необходимо)
  - Перенести After/Wants в `systemd.services.polkit.after`/`.wants` (в секцию Unit) и добавить `serviceConfig.RestartSec = "3s"`.
  - Опционально указать `services.dbus.implementation = "broker"`.

3) Рефакторинг configuration.nix (низкий‑средний риск)
  - Вынести блоки boot, nix, locale, services, systemd‑policy, packages-runtime в отдельные модули в `modules/`.
  - Оставить `configuration.nix` тонким композитором: импорт модулей и финальная `environment.systemPackages = lib.mkForce (...)`.

4) Тесты и CI (низкий риск)
  - Добавить тесты: проверка наличия /run/current-system/sw/bin/{bash,ssh} и проверка, что в собранном unit'е polkit содержит `After=dbus.service`.
  - Расширить flake check: build toplevel + запуск тестов.

5) Операционная страховка
  - В `scripts/switch.sh` (или just) добавить fallback: при обнаружении текста "Rejected send message" в выводе — выполнить `nixos-rebuild boot` и предложить reboot.

Критика плана (коротко)
------------------------
- Быстрый фикс устраняет симптомы, но не гарантирует отсутствие гонки при живой активации. Поэтому важно выполнить шаг 2.
- Рефакторинг должен быть по‑этапным: сначала вынести небольшие модули, проверить сборку, затем перенести остальные блоки.

Ожидаемые результаты
---------------------
- Сборка снова содержит bash и ssh в sw/bin.
- Live switch больше не даёт Rejected send message в тестовой VM.
- Конфигурация модульна и более безопасна для будущих изменений.
