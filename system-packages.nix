#!/usr/bin/env nix
# Список системных пакетов и вспомогательных утилит
#
# Назначение:
# Определяет набор пакетов, включаемых в environment.systemPackages для
# рабочих станций и серверов в этом профиле. Набор покрывает несколько зон:
# - локальная рабочая станция (GUI, мультимедиа, утилиты),
# - разработка и сборка (компиляторы, Haskell/Node/Python инструменты),
# - приватность и сетевые слои (Tor, VPN, overlay сети),
# - агенты/LLM и вспомогательные инструменты (ollama, pipx-утилиты),
# - инфраструктурные утилиты для кластеров и операций (headscale, wireguard, yggdrasil).
{ pkgs, emacsPkg ? pkgs.emacs, enableOptional ? false, opencodeBackend ? null }:

let
  emacsPackages = pkgs.emacsPackagesFor emacsPkg;
  # Emacs как учебная платформа
  #
  # Emacs выполняет несколько ролей в рабочем контуре: текстовый редактор,
  # среда для разработки (LSP, REPL), менеджер окон (EXWM) и платформа для агентов
  # и интеграции с LLM/инструментами AI. Здесь мы формируем воспроизводимый
  # emacsRuntime с набором пакетов, который обеспечивает эти функции.
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

  

  llmResearchEnv = pkgs.python3.withPackages (ps: with ps; [
    jupyterlab
    ipykernel
    transformers
    datasets
    sentencepiece
    tokenizers
    numpy
    pandas
    matplotlib
    scipy
    plotly
    seaborn
  ]);

  llmLabCmd = pkgs.writeShellScriptBin "llm-lab" ''
    # Запускаем notebook/lab в воспроизводимом Python-контуре для экспериментов
    # с моделями, эмбеддингами, датасетами и RAG-пайплайнами.
    export JUPYTER_PATH="${llmResearchEnv}/share/jupyter"
    exec ${llmResearchEnv}/bin/jupyter-lab "$@"
  '';

  

  

  # Utility to install/update a local per-user opencode binary in a well-known
  # location. The repository previously included a local `.opencode/` checkout
  # and node_modules which caused builds to attempt packaging opencode plugins.
  # Those sources are removed from the flake; the supported runtime is the
  # Home Manager `programs.opencode-bwrap` wrapper which runs opencode in a
  # bubblewrap sandbox. Keep this helper for users who explicitly want to
  # install a local copy via `opencode-install-local` at runtime.

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

  # Вынесенные вспомогательные обёртки - чтобы rawList содержал только
  # ссылки на уже построенные деривации, а не inline-выражения.
  nixGuiCmd = pkgs.writeShellScriptBin "nix-gui" ''
    exec ${pkgs.nix}/bin/nix --experimental-features 'nix-command flakes' run github:nix-gui/nix-gui -- "$@"
  '';

  # Use explicit pkgs.chromium reference to avoid depending on local var name.
  chromiumCmd = pkgs.writeShellScriptBin "chromium" ''
    exec systemd-run --user --scope -p MemoryMax=4500M -p MemoryHigh=4G -p CPUQuota=90% -- ${pkgs.chromium}/bin/chromium "$@"
  '';

  firefoxCmd = pkgs.writeShellScriptBin "firefox" ''
    exec systemd-run --user --scope -p MemoryMax=2500M -p MemoryHigh=2G -p CPUQuota=90% -- ${pkgs.firefox}/bin/firefox "$@"
  '';

  torBrowserCmd = pkgs.writeShellScriptBin "tor-browser" ''
    exec ${pkgs.tor-browser}/bin/tor-browser "$@"
  '';

  emacsPanicCmd = pkgs.writeShellScriptBin "emacs-panic" ''
    pkill -INT -u "$USER" -x emacs >/dev/null 2>&1 || pkill -INT -u "$USER" -f 'emacs.*daemon' >/dev/null 2>&1 || true
  '';

  piDevCmd = pkgs.writeShellScriptBin "pi-dev" ''
    exec pi "$@"
  '';
in

with pkgs;

let
  optionalPackages = [
    chromium
    firefox
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

  # Пояснение по optionalPackages:
  # Сюда включены тяжёлые или опциональные программы (браузеры, GUI-приложения,
  # игровые платформы, крупные медиа-инструменты). По умолчанию эти пакеты
  # отключены (enableOptional=false) и включаются явным флагом, чтобы не
  # перегружать профиль лишним ПО на серверах или в минимальных окружениях.

in

  # Основной набор пакетов
  # Ниже — базовый набор пакетов, полезный для рабочего поля разработчика и
  # администратора. Пакеты организованы по группам: редакторы, утилиты,
  # диагностика, приватность и сети, сборка и языки разработки, медиа.
  let rawList = (if enableOptional then optionalPackages else []) ++ [
  kbd
  # Редактор и связанные пакеты: инструменты для работы с текстом, ссылками и навигацией.
  emacsRuntime
  direnv
  acpi
  xvfbRun

  # Общие утилиты составляют инструментальный фон и упрощают выполнение задач.
  nixGuiCmd
  wget
  diffutils
  curl
  jq
  just
git
gh
  shellcheck
  shfmt
  bat
  tldr
   piDevCmd
  
  pipxPkg
    
  llmLabCmd
    
  htop
  neofetch
  feh
   xterm
  pcmanfm
  xfce.thunar
  ffmpegthumbnailer      # Видео-миниатюры для tumbler
  lm_sensors            # Мониторинг датчиков (температура/вентиляторы).
  stress-ng             # CPU/memory stress testing tool
  fio                   # Flexible I/O tester for disks
  time                  # GNU time for precise timing measurements
  powertop              # Power consumption and CPU frequency diagnostics
  #python3Full           # python3 и python (совместимость с shebang и stubs).
  nodejs_20
  # Make sure real python binaries are present globally in the pro-nix profile
  # so scripts and shebangs can rely on /run/current-system/sw/bin/python and python3.
   python3
  esbuild
  nodePackages.prettier # Форматирование JS/TS для Apheleia (Emacs).
  # Language servers and tree-sitter tooling (system-wide)
  # JavaScript / TypeScript
  nodePackages.typescript-language-server
  nodePackages.typescript
  # Tree-sitter CLI: позволяет пользователю (через Emacs/tree-sitter-langs или
  # M-x treesit-install-language-grammar) собрать грамматики локально в
  # ~/.config/emacs/tree-sitter без необходимости system-wide сборки .so.
  (if builtins.hasAttr "tree-sitter-cli" pkgs then pkgs.tree-sitter-cli else null)
  # Tree-sitter tooling: grammars are provided via a dedicated derivation
  # (nix/treesitter-grammars.nix). We do not require the CLI in system
  # packages here to avoid depending on an attribute that may not exist
  # in the chosen nixpkgs channel.
  # Popular/reliable LSP servers (system-wide)
  # Python: pyright
  (if builtins.hasAttr "nodePackages" pkgs && builtins.hasAttr "pyright" pkgs.nodePackages then pkgs.nodePackages.pyright else null)
  # Java: Eclipse JDT Language Server
  (if builtins.hasAttr "jdtls" pkgs then pkgs.jdtls else null)
  (if builtins.hasAttr "jdtls" pkgs && builtins.hasAttr "openjdk" pkgs then pkgs.openjdk else null)
  # JSON/YAML: language servers extracted from VS Code extensions
  (if builtins.hasAttr "vscode-langservers-extracted" pkgs then pkgs.vscode-langservers-extracted else null)
  # Rust: rust-analyzer
  (if builtins.hasAttr "rust-analyzer" pkgs then pkgs.rust-analyzer else null)
  # Go: gopls
  (if builtins.hasAttr "goPackages" pkgs && builtins.hasAttr "gopls" pkgs.goPackages then pkgs.goPackages.gopls else null)
  # Bash: bash-language-server
  (if builtins.hasAttr "nodePackages" pkgs && builtins.hasAttr "bash-language-server" pkgs.nodePackages then pkgs.nodePackages."bash-language-server" else null)
  # Additional explicit LSPs where available: vscode extracted servers and gopls/pyright already guarded above
  (if builtins.hasAttr "nodePackages" pkgs && builtins.hasAttr "vscode-langservers-extracted" pkgs.nodePackages then pkgs.nodePackages."vscode-langservers-extracted" else null)
  (if builtins.hasAttr "nodePackages" pkgs && builtins.hasAttr "pyright" pkgs.nodePackages then pkgs.nodePackages.pyright else null)
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

  # Апплеты и tray-серверы без привязки к конкретной среде обеспечивают переносимость между оболочками.
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
  # Обёртки перемещены выше как готовые деривации, чтобы rawList содержал только
  # ссылки на уже созданные пакеты/скрипты.
  chromiumCmd
  firefoxCmd
  torBrowserCmd
  emacsPanicCmd

  # Мессенджеры находятся рядом с остальными каналами связи.
  telegram-desktop

  # Диагностика и сетевые утилиты сгруппированы вместе.
  lsof
  iftop
  iotop
  iperf3
  iputils
  dnsutils
  ncdu
  atop
  cifs-utils
  avahi
  
   # ────────────────────────────────────────────────────────────────────────────
   # Анонимность и децентрализованные сети — учебный блок
   # ────────────────────────────────────────────────────────────────────────────
   # Здесь представлены инструменты и трансопрты для построения приватных
   # каналов связи: Tor и сопутствующие транспорты, инструменты мониторинга
   # и утилиты для тестирования приватности. Комментарии поясняют, где и как
   # применять эти пакеты в практических сценариях.

  # Tor и обфускация формируют слой, в котором адреса перестают быть прямой формой доступа.
  tor                     # Tor клиент (системный сервис)
  torsocks                # Проксирование приложений через Tor (torify)
  torBrowserCmd           # Системный launcher для Tor Browser.
  obfs4                   # obfs4 transport для обхода DPI
  # OpenSSL: необходим для отладки TLS (openssl s_client) и других
  # низкоуровневых операций с сертификатами. Добавляем в systemPackages
  # чтобы инструмент был доступен в PATH для локальной диагностики Tor.
  openssl
  snowflake               # Snowflake мосты (WebRTC-маскировка)
  nyx                     # Мониторинг Tor в реальном времени (htop-подобный интерфейс)
  onionshare              # Анонимный файлообмен через Tor

   # I2P представляет альтернативную приватную сеть.
   i2p                     # I2P роутер и клиент
   # Применение: I2P подходит для P2P и скрытых сервисов (eepsites); выбирается
   # когда требуется иная модель адресации и маршрутизации, чем у Tor.

  # DNSCrypt обеспечивает шифрование запросов DNS.
  dnscrypt-proxy          # DNS-over-HTTPS/TLS прокси

  # Проксирование произвольных приложений изменяет маршрут сетевого трафика без правок в программах.
  proxychains             # Проксирование любых приложений через Tor/SOCKS
  # Использование: proxychains <команда> (например: proxychains curl https://example.com)

  # VPN и туннели остаются резервным контуром связи на случай, когда основная сеть требует обхода или изоляции.
  mullvad-vpn             # Mullvad VPN (официальный пакет, приватный)
  wireguard-tools         # WireGuard — современный VPN-протокол
  yggdrasil               # Децентрализованная overlay-сеть (IPv6 поверх любого транспорта)
  # zerotierone           # ZeroTier — альтернатива Yggdrasil (build hangs, use nix-shell if needed)

  # Децентрализованные мессенджеры предоставляют каналы без единой точки центра.
  # Session временно убран: текущая версия не собирается локально и не берётся из кэша.
  element-desktop         # Matrix-клиент, который держит федеративную переписку в рабочем поле.
  jami                    # Jami, где P2P сохраняет разговор без центрального узла.
  weechat                 # IRC-клиент, который хорошо сочетается с Tor и консольной дисциплиной.

  # Утилиты для проверки анонимности позволяют убедиться в работоспособности приватных каналов.
  curl                    # Проверка Tor: `curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org`
  wget                    # Резервный загрузчик для тех моментов, когда нужен простой и предсказуемый транспорт.

  # ────────────────────────────────────────────────────────────────────────────
   # Сетевая устойчивость: туннели и overlay (пояснение)
  # ────────────────────────────────────────────────────────────────────────────
  obfs4                 # Pluggable transports для мостов Tor.
  torsocks              # Проксирование приложений через Tor.
  torBrowserCmd         # Системный launcher для Tor Browser.
  
  # Федеративные и децентрализованные мессенджеры продолжают ту же линию, но уже без привязки к браузеру.
  element-desktop       # Matrix-клиент.
  weechat               # IRC-клиент в консольной форме.
  
   # Инструменты сборки и компиляции
   # Набор инструментов для сборки и компиляции (gcc, cmake, make и т.д.)
   # требуется для локальной сборки пакетов, разработки и отладки зависимостей.
  cmake
  gcc
  binutils
  gnumake
  pkg-config
  ncurses
  libtool
  automake
  autoconf
  
   # Вспомогательные средства для EXWM и Emacs
   # Эти пакеты поддерживают интеграцию Emacs с X11/окружением (EXWM, xbindkeys,
   # xdotool и т.д.) и используются в сценариях, где Emacs выступает как WM.
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
  ripgrep
  fd
  findutils
  mc
  tmux
  fzf
  tree
  lnav
  mosh

   # Темы курсора X11 — оформительская настройка указателя мыши.
  xorg.xcursorthemes
  pkgs.adwaita-icon-theme
  
   # Медиа: аудио и видео
   # Пакеты для воспроизведения и обработки мультимедиа.
  ffmpeg-full
  vlc
  mpv
  jami

   # Торрент-клиенты выделены в отдельную категорию транспортов (P2P).
  #transmission
  #transmission-gtk
  deluge

  # Слот для мониторинга безопасности (не заполнен).

   # Диаграммы и средства визуализации
   # Набор инструментов для генерации диаграмм и схем (graphviz, plantuml,
   # mermaid). Полезно для документирования архитектуры и построения учебных
   # материалов.
  graphviz           # Рендеринг графов; иногда служит почвой для PlantUML.
  plantuml           # Генератор UML-диаграмм и одноимённая команда.
  nodePackages.mermaid-cli  # Утилита `mmdc` для рендеринга Mermaid.

  pandoc                # Универсальный конвертер документов.

  # Офисные приложения и поддержка разработки
  # Здесь собраны инструменты, которые полезны при создании документации,
  # сборке отчетов и интеграции с рабочим процессом разработки.i
  
  clamav
  # haskell
  haskellPackages.haskell-language-server
  emacsPackages.eldev
  emacsPackages.cask

  evince
  zathura
  
  # Python-обёртки: единый исполняемый контур
  # Обёртки `python`, `python3`, `pip`, `pip3` направляют вызовы в
  # воспроизводимый интерпретатор (myPython). Это уменьшает рассинхронизацию
  # между системным окружением и пользовательскими виртуальными средами.
  pythonCmd
  python3Cmd
  pipCmd
  pip3Cmd
  ];
in

let
  treesitterGrammars = import ./nix/treesitter-grammars.nix { inherit pkgs; };
in
{
  # Основной список системных пакетов без `null`.
  packages = builtins.filter (x: x != null) (rawList ++ [ treesitterGrammars ]);

  
}
