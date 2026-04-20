{ pkgs, emacsPkg ? pkgs.emacs, enableOptional ? false }:

let
  emacsPackages = pkgs.emacsPackagesFor emacsPkg;
  emacsRuntime = emacsPackages.emacsWithPackages (epkgs: with epkgs; [
    magit
    ligature
    kind-icon
    nerd-icons
    treemacs-icons-dired
    nerd-icons-ibuffer
    eldoc-box
    nix-mode
    exwm
  ]);
  xvfbRun = pkgs."xvfb-run";
  pipxPkg = pkgs.pipx;

  aiderCmd = pkgs.writeShellScriptBin "aider" ''
    # Run under a user transient scope so a runaway agent can't fully saturate CPU.
    exec systemd-run --user --scope -p CPUQuota=60% -p CPUWeight=150 ${pipxPkg}/bin/pipx run aider-chat -- "$@"
  '';

  opencodeCmd = pkgs.writeShellScriptBin "opencode" ''
    # Run opencode under a user transient scope with CPU limits to avoid heavy spikes.
    exec systemd-run --user --scope -p CPUQuota=60% -p CPUWeight=150 ${pkgs.nodejs_20}/bin/npx --yes @opencode/cli -- "$@"
  '';

  # Python-слой здесь держит минимальную воспроизводимость: `requests` уже есть, а `pip` остаётся доступным для локальных окружений и одноразовых установок.
  myPython = pkgs.python3.withPackages (ps: [ ps.requests ps.pip ]);

  # Так мы фиксируем один Python для всего рабочего поля: `python` и `python3` всегда ведут в один и тот же контур, даже если окружение пытается подменить путь.
  pythonCmd = pkgs.writeShellScriptBin "python" ''
    exec ${myPython}/bin/python3 "$@"
  '';
  python3Cmd = pkgs.writeShellScriptBin "python3" ''
    exec ${myPython}/bin/python3 "$@"
  '';

  # `pip` тоже идёт рядом, чтобы личные окружения можно было поднимать без расхождения с выбранным Python.
  pipCmd = pkgs.writeShellScriptBin "pip" ''
    exec ${myPython}/bin/python3 -m pip "$@"
  '';
  pip3Cmd = pkgs.writeShellScriptBin "pip3" ''
    exec ${myPython}/bin/python3 -m pip "$@"
'';
in

with pkgs;

let
  optionalPackages = [
    chromium
    firefox
    tor-browser
    telegram-desktop
    element-desktop
    jami
    ffmpeg-full
    deluge
    haskellPackages.haskell-language-server
    ollama
    steam
    steam-run
  ];

in

  (if enableOptional then optionalPackages else []) ++ [
  kbd
  # Редакторный контур и его спутники: здесь живут инструменты, которые держат текст, ссылки и навигацию в одном рабочем ритме.
  emacsRuntime
  direnv
  acpi
  xvfbRun

  # Общие утилиты составляют инструментальный фон: они не оформляют идею, а дают ей быстро стать действием.
  (writeShellScriptBin "nix-gui" ''
    exec ${nix}/bin/nix --experimental-features 'nix-command flakes' run github:nix-gui/nix-gui -- "$@"
  '')
  wget
  diffutils
  curl
  jq
  just
git
github-cli
  goose
  pipxPkg
  aiderCmd
  opencodeCmd
  htop
  neofetch
  feh
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

  # Апплеты и tray-серверы без привязки к конкретной среде нужны там, где интерфейс должен переживать смену оболочки.
  volumeicon
  caffeine-ng       # на Linux только caffeine-ng!
  redshift
  flameshot
  batsignal
  playerctl

  # Анализ дискового пространства
  baobab            # GNOME Disk Usage Analyzer (круговая/treemap)
  duc               # Быстрый индексатор + консоль/GUI

  # Браузеры обернуты в мягкий лимит памяти, чтобы графический поток не вытеснял остальной рабочий контур.
  # Обёртки `writeShellScriptBin` намеренно переопределяют стандартные команды и прячут этот предел от повседневной рутины.
  (writeShellScriptBin "chromium" ''
    exec systemd-run --user --scope -p MemoryMax=4500M -p MemoryHigh=4G -p CPUQuota=90% -- ${chromium}/bin/chromium "$@"
  '')
  (writeShellScriptBin "firefox" ''
    exec systemd-run --user --scope -p MemoryMax=2500M -p MemoryHigh=2G -p CPUQuota=90% -- ${firefox}/bin/firefox "$@"
  '')
  (writeShellScriptBin "emacs-panic" ''
    pkill -INT -u "$USER" -x emacs >/dev/null 2>&1 || pkill -INT -u "$USER" -f 'emacs.*daemon' >/dev/null 2>&1 || true
  '')
  tor-browser

  # Мессенджеры здесь находятся рядом с остальными каналами связи, а не отдельно от них.
  telegram-desktop

  # Диагностика и сеть сведены в один набор: он нужен тогда, когда рабочее окружение начинает вести себя как система, а не как интерфейс.
  lsof
  iftop
  iotop
  iperf3
  iputils
  dnsutils
  ncdu
  atop
  
  # ────────────────────────────────────────────────────────────────────────────
  # Анонимность, обход блокировок и децентрализованные сети
  # ────────────────────────────────────────────────────────────────────────────

  # Tor и обфускация образуют слой, в котором адреса перестают быть прямой формой доступа.
  tor                     # Tor клиент (системный сервис)
  torsocks                # Проксирование приложений через Tor (torify)
  tor-browser             # Браузер со встроенным Tor
  obfs4                   # obfs4 transport для обхода DPI
  snowflake               # Snowflake мосты (WebRTC-маскировка)
  nyx                     # Мониторинг Tor в реальном времени (как htop для Tor)
  onionshare              # Анонимный файлообмен через Tor

  # I2P здесь хранится как вторая траектория скрытой связи: не альтернатива, а иной способ присутствовать в сети.
  i2p                     # I2P роутер и клиент
  # i2p лучше подходит для P2P внутри сети и скрытых сервисов (eepsites)

  # DNSCrypt нужен как тихая дисциплина имен: запрос должен идти по защищённому каналу, а не по привычке.
  dnscrypt-proxy          # DNS-over-HTTPS/TLS прокси

  # Проксирование произвольных приложений позволяет не переписывать сами программы, а лишь их путь к миру.
  proxychains             # Проксирование любых приложений через Tor/SOCKS
  # Использование: proxychains <команда> (например: proxychains curl https://example.com)

  # VPN и туннели остаются резервным контуром связи на случай, когда основная сеть требует обхода или изоляции.
  mullvad-vpn             # Mullvad VPN (официальный пакет, приватный)
  wireguard-tools         # WireGuard — современный VPN-протокол
  yggdrasil               # Децентрализованная overlay-сеть (IPv6 поверх любого транспорта)
  # zerotierone           # ZeroTier — альтернатива Yggdrasil (build hangs, use nix-shell if needed)

  # Децентрализованные мессенджеры нужны как каналы, где связь не сводится к одному серверу.
  # Session временно убран: текущая версия не собирается локально и не берётся из кэша.
  element-desktop         # Matrix-клиент, который держит федеративную переписку в рабочем поле.
  jami                    # Jami, где P2P сохраняет разговор без центрального узла.
  weechat                 # IRC-клиент, который хорошо сочетается с Tor и консольной дисциплиной.

  # Утилиты для проверки анонимности нужны не как украшение, а как быстрый способ проверить, что скрытый путь действительно жив.
  curl                    # Проверка Tor: `curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org`
  wget                    # Резервный загрузчик для тех моментов, когда нужен простой и предсказуемый транспорт.

  # ────────────────────────────────────────────────────────────────────────────
  # Сетевая устойчивость: туннели и overlay
  # ────────────────────────────────────────────────────────────────────────────
  obfs4                 # Pluggable transports для мостов Tor.
  torsocks              # Проксирование приложений через Tor.
  tor-browser           # Браузер со встроенным Tor.
  
  # Федеративные и децентрализованные мессенджеры продолжают ту же линию, но уже без привязки к браузеру.
  element-desktop       # Matrix-клиент.
  weechat               # IRC-клиент в консольной форме.
  
  # Инструменты компиляции и сборки образуют техническое ядро, без которого рабочее поле быстро теряет самостоятельность.
  cmake
  gcc
  binutils
  gnumake
  pkg-config
  ncurses
  libtool
  automake
  autoconf
  
  # Вспомогательные средства для EXWM и Emacs держат оконную и текстовую среду в одном жесте управления.
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

  # Темы курсора X11 нужны как визуальная интонация, а не как отдельный дизайн-проект.
  xorg.xcursorthemes
  pkgs.adwaita-icon-theme
  
  # Аудио и видео работают как бытовая акустика рабочего места.
  ffmpeg-full
  vlc
  mpv
  jami

  # Торрент-клиенты оставлены как отдельный транспортный контур.
  #transmission
  #transmission-gtk
  deluge

  # Здесь мог бы стоять мониторинг безопасности; сейчас этот слот оставлен как напоминание о границе между инструментом и наблюдением.

  # Диаграммы и визуализация нужны, когда мысль должна выйти из текста и стать схемой.
  graphviz           # Рендеринг графов; иногда служит почвой для PlantUML.
  plantuml           # Генератор UML-диаграмм и одноимённая команда.
  nodePackages.mermaid-cli  # Утилита `mmdc` для рендеринга Mermaid.

  pandoc                # Универсальный конвертер документов.

  # Офисные приложения держат документальный слой рядом с кодом, а не отдельно от него.
  #clamav
  # haskell
  haskellPackages.haskell-language-server
  emacsPackages.eldev
  emacsPackages.cask

  evince
  zathura
  
  # Финальные Python-обёртки закрывают цикл: любой вызов из PATH попадает в один и тот же исполняемый контур.
  pythonCmd
  python3Cmd
  pipCmd
  pip3Cmd
]
