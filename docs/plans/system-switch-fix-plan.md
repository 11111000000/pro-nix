# План исправления: устранение гонки dbus/polkit и рефакторинг конфигурации

Цель
- Устранить причину отказа live activation (Rejected send message) и структурно уменьшить риск регрессий путём модульного рефакторинга configuration.nix.

Ключевые шаги
1) Невыносимо быстрый (операционный) путь
   - Добавить обязательные рантайм-пакеты (`bashInteractive`, `openssh`) в top-level `environment.systemPackages` (уже сделано).
   - До завершения рефакторинга использовать `nixos-rebuild boot && reboot` на production-хостах.

2) Минимальный кодовый фикс (низкий риск)
   - Правильно задать ordering и зависимости для polkit:
     - systemd.services.polkit.after = [ "dbus.service" "sysinit-reactivation.target" ];
     - systemd.services.polkit.wants = [ "dbus.service" ];
     - systemd.services.polkit.serviceConfig.RestartSec = "3s";
   - Зафиксировать реализацию dbus (broker) в конфигурации: services.dbus.implementation = "broker".

3) Рефакторинг конфигурации (уменьшение blast radius)
   - Разделить configuration.nix на модули:
     a) modules/system-boot.nix — boot.* и kernel
     b) modules/system-locale.nix — i18n, time, sudo
     c) modules/system-nix.nix — nix.settings, substituters, gc
     d) modules/system-services.nix — поведение базовых сервисов (libinput, bluetooth, upower, xdg.portal)
     e) modules/systemd-policy.nix — systemd.oomd, polkit/unit ordering, dbus implementation
     f) modules/packages-runtime.nix — минимальный runtime-пакетлист (bash, openssh, coreutils, dbus)
   - configuration.nix становится thin-compositor, который импортирует перечисленные модули и лишь консолидирует environment.systemPackages.

4) Тесты и верификация
   - Добавить тесты:
     - tests/contract/test_system_runtime_paths.spec — проверка существования /run/current-system/sw/bin/{bash,ssh}
     - tests/contract/test_polkit_unit_order.sh — после сборки toplevel проверяет, что unit polkit содержит After=dbus.service
   - CI: добавить стадию для сборки huawei toplevel и запуска этих тестов (можно в виде simple shell проверок).

5) Операционный фоллбек
   - Обновить scripts/switch.sh: при обнаружении в выводе `Rejected send message` — автоматически выполнить `nixos-rebuild boot` и предложить перезагрузиться.

Оценка рисков
- Низкий: добавление runtime пакетов и корректировка unit-атрибутов.
- Средний: переключение реализации dbus (broker) — но это современное и рекомендуемое значение для NixOS.
- Низкий: модульный рефакторинг уменьшает риск и облегчает тестирование.

Критерии успеха
- Build huawei toplevel проходит
- Contract тесты проходят
- Live switch не вызывает `Rejected send message` в VM-проверке
