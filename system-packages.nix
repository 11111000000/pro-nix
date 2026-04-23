# Учебный модуль: системные пакеты и вспомогательные утилиты
#
# Назначение:
# Определяет набор пакетов, ожидаемых в системной среде и включаемых в
# systemPackages. Комментарии здесь объясняют назначение групп пакетов и
# причины включения. Модуль не предназначен для полной универсальности —
# он служит примером организации набора инструментов для рабочего поля.
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
    # Запуск в пользовательской transient-сессии, чтобы ограничить потребление CPU
    # у потенциально долгоживущих агентов.
    exec systemd-run --user --scope -p CPUQuota=60% -p CPUWeight=150 "${pipxPkg}/bin/pipx" run aider-chat -- "$@"
  '';

  # Детерминированный пакет: скачивает официальную сборку opencode и помещает
  # её в Nix store. Этот код даёт воспроизводимый бинарный артефакт на случай,
  # если flake не предоставляет готовую версию.
  opencodeBin = pkgs.stdenv.mkDerivation rec {
    pname = "opencode";
    version = "1.14.19";
    src = pkgs.fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v1.14.19/opencode-linux-x64.tar.gz";
      sha256 = "8cb11723ce0ec82e2b6ff9a2356b12c2f4c4a95a087ba0a3004b19f167951440";
    };
    nativeBuildInputs = [ pkgs.patchelf ];
    buildInputs = [];
    unpackPhase = ''
      mkdir -p $TMPDIR/unpack
      tar xzf "$src" -C $TMPDIR/unpack
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp $TMPDIR/unpack/opencode $out/bin/
      chmod +x $out/bin/opencode
      if [ -x "$out/bin/opencode" ]; then
        patchelf --set-interpreter "${pkgs.glibc}/lib/ld-linux-x86-64.so.2" "$out/bin/opencode" || true
        patchelf --set-rpath "${pkgs.glibc}/lib" "$out/bin/opencode" || true
      fi
    '';
  };

  

  # Обёртка для CLI opencode — учебное пояснение
  # В некоторых окружениях upstream npm-пакет `@opencode/cli` может быть недоступен.
  # Обёртка реализует детерминированное поведение в рантайме по следующему порядку:
  # 1) Использовать пользовательский бинарник, если он присутствует (~/.local/bin или ~/.opencode/bin).
  # 2) Если его нет — попробовать загрузить официальный релиз для linux x64 и закешировать его в ~/.local/share/opencode/opencode.
  # 3) Запускать бинарник под user transient systemd scope с ограничением ресурсов.
  opencodeCmd = pkgs.writeShellScriptBin "opencode" ''
    set -euo pipefail

    # Пути, в которых ищем существующий бинарник
    USER_LOCAL_BIN="$HOME/.local/bin/opencode"
    OPENCODE_HOME="$HOME/.opencode/bin/opencode"
    CACHED="$HOME/.local/share/opencode/opencode"

    # Предпочитаем бинарник из Nix store, если он совместим. Это снижает риск
    # выполнения повреждённой версии из пользовательского кеша. Если store-бинарь
    # отсутствует или не проходит быстрый тест работоспособности — используем
    # порядок поиска user-local -> home -> cached -> bootstrap.
    if [ -n "$${OPENCODE_STORE_PATH:-}" ]; then
      STORE_BIN="$${OPENCODE_STORE_PATH%/}/bin/opencode"
    else
      STORE_CAND=$(ls -d /nix/store/*opencode* 2>/dev/null | head -n1 || true)
      if [ -n "$STORE_CAND" ]; then
        STORE_BIN="$STORE_CAND/bin/opencode"
      else
        STORE_BIN=""
      fi
    fi
    # Быстрая проверка работоспособности store-бинарника: если он падает на
    # вызове --version, считаем его несовместимым и пропускаем.
    if [ -x "$STORE_BIN" ]; then
      if command -v timeout >/dev/null 2>&1; then
        if timeout 2s "$STORE_BIN" --version >/dev/null 2>&1; then
          BIN="$STORE_BIN"
        else
          echo "[opencode] store binary present but failed quick check, skipping" >&2
          BIN=""
        fi
      else
        # No timeout utility; attempt a simple invocation and trust it on success
        if "$STORE_BIN" --version >/dev/null 2>&1; then
          BIN="$STORE_BIN"
        else
          BIN=""
        fi
      fi
    else
      choose_exec() {
        if [ -x "$USER_LOCAL_BIN" ]; then
          echo "$USER_LOCAL_BIN"
        elif [ -x "$OPENCODE_HOME" ]; then
          echo "$OPENCODE_HOME"
        elif [ -x "$CACHED" ]; then
          echo "$CACHED"
        else
          echo ""
        fi
      }

      BIN=$(choose_exec)
    fi

    if [ -z "$BIN" ]; then
      # Попытка загрузить официальный релиз для linux x64. Это запасной,
      # best-effort метод; при неудаче скрипт завершится с ошибкой и оператор
      # установит бинарник вручную.
      mkdir -p "$(dirname "$CACHED")"
      echo "[opencode] bootstrap: downloading official release to $CACHED"

      # Quick guard: only attempt bootstrap for supported architecture.
      arch=$(uname -m)
      if [ "$arch" != "x86_64" ]; then
        echo "[opencode] no prebuilt release available for architecture: $arch" >&2
        echo "Please install opencode via Nix (system package) or ask the administrator to provide a compatible binary." >&2
        exit 1
      fi

      # Надёжное создание временной директории: предпочтение TMPDIR, затем /tmp,
      # затем $HOME/.cache/tmp.
      TMPBASE="${TMPDIR:-/tmp}"
      if [ ! -d "$TMPBASE" ]; then
        TMPBASE="$HOME/.cache/tmp"
      fi
      mkdir -p "$TMPBASE" 2>/dev/null || true

      tmpdir=$(mktemp -d "${TMPBASE}/opencode.XXXXXX" 2>/dev/null || mktemp -d 2>/dev/null || printf "%s" "${TMPBASE}/opencode.$(date +%s).$$")
      mkdir -p "$tmpdir" 2>/dev/null || true
      if [ ! -d "$tmpdir" ]; then
        echo "[opencode] cannot create temporary directory (TMPBASE=$TMPBASE)" >&2
        ls -ld "$TMPBASE" || true
        exit 1
      fi

      tmpball="$tmpdir/opencode.tar.gz"
      trap 'rm -rf "$tmpdir"' EXIT

      if command -v curl >/dev/null 2>&1; then
        curl -fSL -o "$tmpball" "https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64.tar.gz"
      elif command -v wget >/dev/null 2>&1; then
        wget -qO "$tmpball" "https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64.tar.gz"
      else
        echo "[opencode] cannot bootstrap: install curl or wget, or place opencode in $USER_LOCAL_BIN" >&2
        exit 1
      fi

      # Извлечь архив во временную папку и переместить атомарно, чтобы не оставить
      # частичный бинарник в кеше.
      tar xzf "$tmpball" -C "$tmpdir"
      if [ -x "$tmpdir/opencode" ]; then
        mv "$tmpdir/opencode" "$CACHED"
        chmod +x "$CACHED"
        BIN="$CACHED"
      else
        echo "[opencode] bootstrap failed: archive did not contain opencode binary" >&2
        exit 1
      fi
    fi

    # Запуск бинарника: учёт особенностей NixOS и upstream-предположений.
    # - Некоторые предсобранные бинарники ожидают стандартную иерархию FHS и
    #   падают на NixOS. В таких случаях полезен steam-run (FHS-обёртка).
    # - Сначала пробуем запустить напрямую с системным динамическим загрузчиком
    #   (glibc loader). Если это не помогает и доступен steam-run, используем его.
    # - Если steam-run недоступен, запускаем под systemd-run с ограничением
    #   ресурсов.
    # - Для интерактивных команд (acp, acp-shell) и если OPENCODE_DIRECT_RUN=1,
    #   нужно сохранить stdin/stdout — тогда выполняем бинарник напрямую.
    if [ "$${OPENCODE_DIRECT_RUN:-0}" = "1" ] || [ "$${1:-}" = "acp" ] || [ "$${1:-}" = "acp-shell" ]; then
      # Прямой exec: передаём все аргументы без изменений.
      exec "$BIN" "$@"
    fi

    if command -v steam-run >/dev/null 2>&1; then
      STEAM_RUN_CMD=$(command -v steam-run)
      # Передача аргументов через steam-run без изменений.
      exec "$STEAM_RUN_CMD" "$BIN" "$@"
    else
      # Для systemd-run требуется разделитель `--' перед командой, чтобы
      # отделить опции systemd-run от аргументов запускаемого процесса.
      exec systemd-run --user --scope -p CPUQuota=60% -p CPUWeight=150 -- "$BIN" "$@"
    fi
  '';
  # Примечание: flake/flake.nix может предоставлять opencode_bin; в этом
  # файле реализован запасной механизм, чтобы модуль работал автономно.

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
  # Редактор и связанные пакеты: инструменты для работы с текстом, ссылками и навигацией.
  emacsRuntime
  direnv
  acpi
  xvfbRun

  # Общие утилиты составляют инструментальный фон и упрощают выполнение задач.
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
  opencodeBin
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
  # Обёртки `writeShellScriptBin` переопределяют команды для применения ограничений ресурсов.
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
  # Анонимность, обход блокировок и децентрализованные сети
  # ────────────────────────────────────────────────────────────────────────────

  # Tor и обфускация образуют слой, в котором адреса перестают быть прямой формой доступа.
  tor                     # Tor клиент (системный сервис)
  torsocks                # Проксирование приложений через Tor (torify)
  tor-browser             # Браузер со встроенным Tor
  obfs4                   # obfs4 transport для обхода DPI
  snowflake               # Snowflake мосты (WebRTC-маскировка)
  nyx                     # Мониторинг Tor в реальном времени (htop-подобный интерфейс)
  onionshare              # Анонимный файлообмен через Tor

  # I2P представляет альтернативную приватную сеть.
  i2p                     # I2P роутер и клиент
  # I2P подходит для P2P внутри сети и скрытых сервисов (eepsites)

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
  ripgrep
  fd
  findutils

  # Темы курсора X11 определяют стиль указателя.
  xorg.xcursorthemes
  pkgs.adwaita-icon-theme
  
  # Аудио и видео составляют медиаподсистему рабочего места.
  ffmpeg-full
  vlc
  mpv
  jami

  # Торрент-клиенты выделены в отдельную категорию транспортов.
  #transmission
  #transmission-gtk
  deluge

  # Слот для мониторинга безопасности (не заполнен).

  # Диаграммы и средства визуализации для генерации схем и графов.
  graphviz           # Рендеринг графов; иногда служит почвой для PlantUML.
  plantuml           # Генератор UML-диаграмм и одноимённая команда.
  nodePackages.mermaid-cli  # Утилита `mmdc` для рендеринга Mermaid.

  pandoc                # Универсальный конвертер документов.

  # Офисные приложения размещены рядом с инструментами разработки.
  #clamav
  # haskell
  haskellPackages.haskell-language-server
  emacsPackages.eldev
  emacsPackages.cask

  evince
  zathura
  
  # Python-обёртки обеспечивают единый Python-интерпретатор в PATH.
  pythonCmd
  python3Cmd
  pipCmd
  pip3Cmd
]
