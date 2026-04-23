# Файл: автосгенерированная шапка — комментарии рефакторятся
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
    exec systemd-run --user --scope -p CPUQuota=60% -p CPUWeight=150 "${pipxPkg}/bin/pipx" run aider-chat -- "$@"
  '';

  # Deterministic package: fetch official release tarball and expose
  # a Nix store package for opencode. Kept here so this module works
  # standalone even when opencode_from_release is not provided by the
  # flake specialArgs.
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

  

  # Provide a small, robust wrapper for the `opencode` CLI.
  # The upstream npm package (`@opencode/cli`) is not always available in the
  # registry in environments where this repo runs. Instead of relying on npx,
  # prefer the following order at runtime:
  # 1. If a user-local opencode binary exists (~/.local/bin/opencode or ~/.opencode/bin/opencode) use it
  # 2. If not present, attempt to download the official Linux x64 release tarball
  #    from GitHub releases and cache it under ~/.local/share/opencode/opencode
  # 3. Run the binary under a user transient systemd scope to limit CPU usage
  opencodeCmd = pkgs.writeShellScriptBin "opencode" ''
    set -euo pipefail

    # Locations we will check for an existing binary
    USER_LOCAL_BIN="$HOME/.local/bin/opencode"
    OPENCODE_HOME="$HOME/.opencode/bin/opencode"
    CACHED="$HOME/.local/share/opencode/opencode"

    # Prefer the deterministic Nix-provided binary when available. This
    # avoids accidentally executing a corrupted user-cached binary in
    # ~/.local/share/opencode/opencode. If a store-provided opencode is not
    # present, fall back to the previous search order (user-local, home,
    # cached, bootstrap).
    # Determine a store-provided opencode binary at runtime. Prefer an
    # explicit environment override OPENCODE_STORE_PATH, otherwise pick the
    # first candidate under /nix/store matching '*opencode*' that contains
    # a bin/opencode executable.
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
    # Prefer a Nix store binary automatically when available and functional.
    # Some upstream prebuilt releases may be incompatible; perform a quick
    # sanity check and skip the store binary if it fails.
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
      # Try to download the official latest release for linux x64. This is a
      # best-effort bootstrap only; failure will fall back to failing fast so
      # the user can install manually via the project's instructions.
      mkdir -p "$(dirname "$CACHED")"
      echo "[opencode] bootstrap: downloading official release to $CACHED"

      # Quick guard: only attempt bootstrap for supported architecture.
      arch=$(uname -m)
      if [ "$arch" != "x86_64" ]; then
        echo "[opencode] no prebuilt release available for architecture: $arch" >&2
        echo "Please install opencode via Nix (system package) or ask the administrator to provide a compatible binary." >&2
        exit 1
      fi

      # Minimal robust temp creation: prefer TMPDIR, fall back to /tmp or $HOME/.cache/tmp
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

      # extract to temp and move atomically to avoid leaving a partial binary
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

    # If the selected binary lives in the Nix store and steam-run is
    # available, run it under steam-run (FHS) as a compatibility fallback.
    # Some upstream prebuilt binaries expect a generic Linux FS layout and
    # fail on NixOS; steam-run is a pragmatic workaround when patchelf is
    # insufficient.
    # Prefer using steam-run if it's available in PATH at runtime. Using an
    # absolute store path here is brittle because steam-run may not be in the
    # system profile; checking PATH makes the wrapper more robust.
    # If BIN is in the Nix store, try running it directly under the
    # Nix glibc dynamic loader first (this often fixes issues where the
    # upstream binary expects a system loader). If that fails and
    # steam-run is available, fall back to steam-run (FHS). Otherwise
    # run normally via systemd-run.
    # Prefer to run the selected binary under steam-run (FHS) when
    # available. This makes upstream prebuilt binaries behave more like a
    # generic Linux environment. If steam-run is not present, fall back to
    # running under systemd-run to limit resource usage.
    # For ACP (opencode acp) we must preserve stdin/stdout and avoid
    # launching the binary via systemd-run/steam-run (they may detach
    # or change stdio handling). Detect common interactive subcommands
    # and honor OPENCODE_DIRECT_RUN to force direct execution.
    if [ "$${OPENCODE_DIRECT_RUN:-0}" = "1" ] || [ "$${1:-}" = "acp" ] || [ "$${1:-}" = "acp-shell" ]; then
      # Directly exec the binary and forward all args unchanged.
      exec "$BIN" "$@"
    fi

    if command -v steam-run >/dev/null 2>&1; then
      STEAM_RUN_CMD=$(command -v steam-run)
      # Forward args unchanged through steam-run
      exec "$STEAM_RUN_CMD" "$BIN" "$@"
    else
      # For systemd-run we must place a separator `--' before the command
      # to separate systemd-run options from the invoked command and its args.
      exec systemd-run --user --scope -p CPUQuota=60% -p CPUWeight=150 -- "$BIN" "$@"
    fi
  '';
  # provide opencodeBin from flake/flake.nix instead of duplicating here
  # (the flake defines opencode_from_release/opencode-release as an app)

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
  ripgrep
  fd
  findutils

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
