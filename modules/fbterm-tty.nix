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
