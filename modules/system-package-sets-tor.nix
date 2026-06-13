{ pkgs, ... }:
with pkgs;

{
  # Лёгкий набор tor-утилит, доступных ГЛОБАЛЬНО (через environment.systemPackages
  # всех хостов). Не включает tor-browser, mullvad-vpn и прочие тяжёлые пакеты —
  # те лежат в system-package-sets-privacy.nix и подключаются только на heavy
  # desktop-хостах.
  #
  # Главное: `pro-tor` и `torwrap` — CLI-утилиты для глобального toggle и
  # обёртки запуска команд через tor proxy. Обе нужны на каждом хосте
  # (laptop, desktop, VM), потому что сценарий использования — "попал в сеть
  # с tor/Orbot, переключил прокси, пошёл дальше".

  torControlPackages = [
    # pro-tor: глобальный toggle tor-proxy для текущей пользовательской сессии.
    # `writeShellApplication` авто-резолвит runtime PATH (coreutils, ip, curl, nc)
    # и проверяет shebang. Скрипт — это `scripts/pro-tor` из pro-nix-репо.
    (writeShellApplication {
      name = "pro-tor";
      runtimeInputs = [ pkgs.coreutils pkgs.iproute2 pkgs.curl pkgs.gnused pkgs.gawk pkgs.netcat pkgs.iputils ];
      text = builtins.readFile ../scripts/pro-tor;
    })
    # torwrap: обёртка для запуска одной команды через найденный tor proxy.
    # Использует pro-tor detect для поиска прокси (local или remote).
    (writeShellApplication {
      name = "torwrap";
      runtimeInputs = [ pkgs.coreutils ];
      text = builtins.readFile ../bin/torwrap;
    })
    # Минимальный runtime для самих скриптов (не CLI, но нужны для torwrap):
    torsocks
    proxychains
  ];
}
