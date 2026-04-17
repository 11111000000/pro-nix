{ pkgs, emacsPkg ? pkgs.emacs }:

let
  # Python окружение, в котором гарантированно есть requests (+ pip для установки пакетов в venv/--user при необходимости)
  myPython = pkgs.python3.withPackages (ps: [ ps.requests ps.pip ]);

  # Делаем так, чтобы команды `python` и `python3` в PATH точно указывали на myPython,
  # независимо от того, что ещё может подтянуться в окружение (Emacs/org-babel часто зовёт `python`).
  pythonCmd = pkgs.writeShellScriptBin "python" ''
    exec ${myPython}/bin/python3 "$@"
  '';
  python3Cmd = pkgs.writeShellScriptBin "python3" ''
    exec ${myPython}/bin/python3 "$@"
  '';

  # Добавляем pip в PATH (через python -m pip), чтобы можно было ставить пакеты в venv/--user.
  pipCmd = pkgs.writeShellScriptBin "pip" ''
    exec ${myPython}/bin/python3 -m pip "$@"
  '';
  pip3Cmd = pkgs.writeShellScriptBin "pip3" ''
    exec ${myPython}/bin/python3 -m pip "$@"
  '';
in

with pkgs; [
  kbd
  # Базовые редакторы и вспомогательные инструменты.
  emacsPkg
  direnv
  acpi

  # Утилиты общего назначения.
  (writeShellScriptBin "nix-gui" ''
    exec ${nix}/bin/nix --experimental-features 'nix-command flakes' run github:nix-gui/nix-gui -- "$@"
  '')
  wget
  diffutils
  curl
git
github-cli
ollama
  htop
  neofetch
  feh
  gimp
  xterm
  pcmanfm
  xfce.thunar
  ffmpegthumbnailer      # Видео-миниатюры для tumbler
  lm_sensors            # Мониторинг датчиков (температура/вентиляторы).
  #python3Full           # python3 и python (совместимость с shebang и stubs).
  nodejs_20
  esbuild
  nodePackages.prettier # Форматирование JS/TS для Apheleia (Emacs).
  networkmanagerapplet  # Индикатор Wi-Fi в трее.
  blueman               # Графический интерфейс для Bluetooth.
  obexd                 # Передача файлов по Bluetooth.
  bluez                 # Полный стек Bluetooth.
  trousers              # Утилиты для TPM.
  sysstat               # Диагностика (iostat и другие).
  pciutils              # lspci — просмотр устройств PCI.
  usbutils              # lsusb — просмотр USB.
  efibootmgr            # Управление EFI-переменными (BootOrder/BootNext).
  alsa-utils            # aplay и другие консольные средства ALSA.
  alsa-ucm-conf         # UCM-профили для современных кодеков (ES8336 и др.), требуются для SOF топологий.
  smartmontools         # Проверка состояния SSD/HDD.
  parted                # Разметка дисков.
  dosfstools            # mkfs.fat, fsck.fat — для FAT.
  exfatprogs            # mkfs.exfat, fsck.exfat — для exFAT.
  ntfs3g                # Утилиты и драйвер NTFS (FUSE).
  snixembed
  pavucontrol
  copyq
  scrot
  udiskie
  dunst
  unzip
  pasystray
  libnotify    

  # DE-neutral applets & tray серверы, используемые в systemd user-сервисах:
  volumeicon
  caffeine-ng       # на Linux только caffeine-ng!
  redshift
  flameshot
  batsignal
  playerctl

  # Анализ дискового пространства
  baobab            # GNOME Disk Usage Analyzer (круговая/treemap)
  duc               # Быстрый индексатор + консоль/GUI

  # Браузеры — запускаются с ограничением памяти (3GB Chromium, 2GB Firefox)
  # (writeShellScriptBin переопределяет стандартные команды)
  (writeShellScriptBin "chromium" ''
    exec systemd-run --user --scope -p MemoryMax=4500M -p MemoryHigh=4G -- ${chromium}/bin/chromium "$@"
  '')
  (writeShellScriptBin "google-chrome" ''
    exec systemd-run --user --scope -p MemoryMax=4500M -p MemoryHigh=4G -- ${google-chrome}/bin/google-chrome "$@"
  '')
  (writeShellScriptBin "firefox" ''
    exec systemd-run --user --scope -p MemoryMax=2500M -p MemoryHigh=2G -- ${firefox}/bin/firefox "$@"
  '')
  (writeShellScriptBin "emacs-panic" ''
    exec /home/zoya/.local/bin/emacs-panic "$@"
  '')
  tor-browser

  # Месенджеры
  telegram-desktop

  # Диагностические и сетевые средства.
  lsof
  iftop
  iotop
  iperf3
  iputils
  dnsutils
  ncdu
  atop
  
  # ────────────────────────────────────────────────────────────────────────────
  # АНОНИМНОСТЬ, ОБХОД ЦЕНЗУРЫ И ДЕЦЕНТРАЛИЗОВАННЫЕ СЕТИ
  # ────────────────────────────────────────────────────────────────────────────

  # --- Tor и обфускация ---
  tor                     # Tor клиент (системный сервис)
  torsocks                # Проксирование приложений через Tor (torify)
  tor-browser             # Браузер со встроенным Tor
  obfs4                   # obfs4 transport для обхода DPI
  snowflake               # Snowflake мосты (WebRTC-маскировка)
  nyx                     # Мониторинг Tor в реальном времени (как htop для Tor)
  onionshare              # Анонимный файлообмен через Tor

  # --- I2P — анонимная overlay-сеть ---
  i2p                     # I2P роутер и клиент
  # i2p лучше подходит для P2P внутри сети и скрытых сервисов (eepsites)

  # --- DNSCrypt — шифрование DNS ---
  dnscrypt-proxy          # DNS-over-HTTPS/TLS прокси

  # --- Проксирование произвольных приложений ---
  proxychains             # Проксирование любых приложений через Tor/SOCKS
  # Использование: proxychains <команда> (например: proxychains curl https://example.com)

  # --- VPN и туннели (резервные каналы связи) ---
  mullvad-vpn             # Mullvad VPN (официальный пакет, приватный)
  wireguard-tools         # WireGuard — современный VPN-протокол
  yggdrasil               # Децентрализованная overlay-сеть (IPv6 поверх любого транспорта)
  zerotierone             # ZeroTier — альтернатива Yggdrasil

  # --- Децентрализованные мессенджеры ---
  # Session временно убран: текущая версия не собирается локально и не берётся из кэша
  element-desktop         # Matrix клиент (уже был, децентрализованный)
  jami                    # Jami (уже был, P2P без серверов)
  weechat                 # IRC клиент (уже был, можно использовать с Tor)

  # --- Утилиты для тестирования анонимности ---
  curl                    # Проверка Tor: curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org
  wget                    # Резервный загрузчик

  # ────────────────────────────────────────────────────────────────────────────
  # Сетевая устойчивость: туннели и overlay (原有保留)
  # ────────────────────────────────────────────────────────────────────────────
  obfs4                 # Pluggable transports для Tor bridges
  torsocks              # Проксирование приложений через Tor
  tor-browser           # Браузер с встроенным Tor
  
  # Федеративные/децентрализованные мессенджеры
  element-desktop       # Matrix клиент
  weechat               # IRC клиент (консольный)
  
  # Инструменты компиляции и сборки ПО.
  cmake
  gcc
  binutils
  gnumake
  pkg-config
  ncurses
  libtool
  automake
  autoconf
  
  # Вспомогательные средства для EXWM/Emacs.
  #evremap
  xorg.xset
  xorg.xhost
  xorg.setxkbmap
  xorg.xsetroot
  wmname
  xbindkeys
  xdotool
  procps
  dbus
  coreutils-prefixed
  gnugrep
  silver-searcher
  platinum-searcher

  # Темы курсора X11 (whiteglass и др.)
  xorg.xcursorthemes
  adwaita-icon-theme
  
  # Аудио/видео
  ffmpeg-full
  vlc
  mpv
  jami

  # Торрент-клиенты
  #transmission
  #transmission-gtk
  qbittorrent
  deluge

  # Для мониторинга безопасности

  # Диаграммы и визуализация
  graphviz           # Для рендеринга графов (используется PlantUML для некоторых диаграмм).
  plantuml           # Генератор UML-диаграмм; командa `plantuml` и JAR.
  nodePackages.mermaid-cli  # Утилита `mmdc` для рендеринга Mermaid.

  pandoc                # Универсальный конвертер документов.

  # Офисные приложения
  libreoffice-fresh  # LibreOffice Impress (аналог PowerPoint), Writer, Calc и др.

  #clamav
  # haskell
  haskellPackages.haskell-language-server
  emacsPackages.eldev
  emacsPackages.cask

  evince
  zathura
  
  blender

  # Делает `python` и `python3` в PATH гарантированно указывать на myPython (с requests),
  # чтобы `import requests` работал в org-babel и в любых вызовах из PATH.
  pythonCmd
  python3Cmd
  pipCmd
  pip3Cmd
]
