# Название: modules/fbterm-tty.nix — Fbterm на выбранной TTY
# Summary (EN): Fbterm service on selected TTY for better font rendering
/* RU: Сервис fbterm для выбранного TTY — улучшенное отображение шрифтов в консоли.
   Описание: модуль обеспечивает установку и конфигурацию fbterm на указанных TTY.
*/
# Цель:
#   Запустить fbterm на выбранной консоли (по умолчанию tty2) с
#   TrueType-шрифтами и улучшенным рендерингом.
# Контракт:
#   Опции: systemd.services.fbterm-tty2 (включается на уровне хоста)
#   Побочные эффекты: запускает fbterm на tty2.
# Предпосылки:
#   Требуется пакет fbterm; рекомендуется протестировать перед включением.
# Как проверить (Proof):
#   После активации: переключиться на tty2 (Ctrl+Alt+F2) — увидеть fbterm.
# Last reviewed: 2026-04-25
{ pkgs, lib, ... }:

{
  # Fbterm service для выбранной TTY (например, tty2). Запускает fbterm, который
  # рендерит TrueType-шрифты через fontconfig, даёт более гладкие шрифты и
  # улучшенные цвета по сравнению с классическими виртуальными консолями.

  # Примечание: включайте модуль на уровне хоста (импортом) или копируйте
  # определение сервиса в локальную конфигурацию. Рекомендуется сначала протестировать на одной машине.

  systemd.services.fbterm-tty2 = {
    description = "Fbterm on tty2 (login)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      # Start on tty2 and run login inside fbterm
      ExecStart = "${pkgs.fbterm}/bin/fbterm -s 2 -e /bin/login";
      Restart = "always";
      StandardInput = "tty";
      StandardOutput = "tty";
      TTYPath = "/dev/tty2";
    };
    # Make sure fbterm runs after KMS and getty so tty device is ready.
    after = [ "getty@tty2.service" ];
  };

}
