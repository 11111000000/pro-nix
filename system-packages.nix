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
{ pkgs, emacsPkg ? pkgs.emacs, enableOptional ? false }:

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

  aiderCmd = pkgs.writeShellScriptBin "aider" ''
    # Запуск в пользовательской transient-сессии, чтобы ограничить потребление CPU
    # у потенциально долгоживущих агентов.
    exec systemd-run --user --scope -p CPUQuota=60% -p CPUWeight=150 "${pipxPkg}/bin/pipx" run aider-chat -- "$@"
  '';

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
    if [ -n "''${OPENCODE_STORE_PATH:-}" ]; then
      STORE_BIN="''${OPENCODE_STORE_PATH%/}/bin/opencode"
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
      # Prefer TMPDIR if set, otherwise fall back to /tmp. Use plain $VAR
      # expansions. Avoid embedding the four-character sequence that looks like
      # a Nix interpolation token; write it in parts ("$" "{" "..." "}") if
      # you need to document it, because including the four-character sequence
      # made of dollar, left-brace, dots, right-brace verbatim inside this
      # multiline string would make Nix try to interpolate it.
      TMPBASE="$TMPDIR"
      if [ -z "$TMPBASE" ]; then
        TMPBASE="/tmp"
      fi
      if [ ! -d "$TMPBASE" ]; then
        TMPBASE="$HOME/.cache/tmp"
      fi
      mkdir -p "$TMPBASE" 2>/dev/null || true

      tmpdir=$(mktemp -d "$TMPBASE/opencode.XXXXXX" 2>/dev/null || mktemp -d 2>/dev/null || printf "%s" "$TMPBASE/opencode.$(date +%s).$$")
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
    # - Для любого CLI-вызова с аргументами тоже выполняем бинарник напрямую:
    #   это сохраняет argv без промежуточной прослойки и не ломает subcommands.
    # If caller provided args or explicitly requested direct run, record intent
    # but defer the actual exec until we know whether the binary is ELF and
    # whether we can run it via the Nix glibc loader or steam-run. Running an
    # ELF directly on NixOS often fails with the "stub-ld" message; prefer the
    # loader or steam-run when available. This preserves argv forwarding while
    # avoiding stub-ld failures.
    if [ "$#" -gt 0 ] || [ "''${OPENCODE_DIRECT_RUN:-0}" = "1" ]; then
      WANT_ARG_FORWARD=1
    else
      WANT_ARG_FORWARD=0
    fi

    # Предпочитаем запуск через steam-run (FHS) когда это возможно — многие
    # предсобранные бинарники ожидают стандартную FHS-иерархию и работают
    # корректно только внутри steam-run. Однако steam-run использует bubblewrap
    # и может не работать в ограниченных окружениях (containers / ограничение
    # number of user namespaces). Проверяем возможность создания unprivileged
    # user namespaces перед использованием steam-run.
    can_use_userns=0
    if [ -r /proc/sys/kernel/unprivileged_userns_clone ]; then
      if [ "$(cat /proc/sys/kernel/unprivileged_userns_clone)" = "1" ]; then
        can_use_userns=1
      fi
    fi

    # Если бинарник — ELF (предположительно динамически связанный), попробуем
    # запустить его через подходящий glibc loader из Nix store. Это часто
    # решает проблему "stub-ld" без необходимости использования steam-run
    # (bubblewrap). Только если запуск через loader не сработает — используем
    # steam-run или systemd-run в зависимости от возможностей хоста.
    is_elf=0
    if [ -x "$BIN" ] && head -c4 "$BIN" 2>/dev/null | od -An -t x1 | tr -d ' \n' | grep -iq '^7f454c46'; then
      is_elf=1
    fi

    if [ "$is_elf" = "1" ]; then
      LOADER=$(ls -d /nix/store/*glibc*/lib/ld-linux-x86-64.so.2 2>/dev/null | head -n1 || true)
    else
      LOADER=""
    fi

    # If we were asked to forward argv, pick the safest executor for ELF vs
    # non-ELF cases: prefer loader for ELF, then steam-run if available, and
    # finally systemd-run wrapper. This ensures flags like --help reach the
    # underlying binary instead of triggering stub-ld failures.
    if [ "${WANT_ARG_FORWARD:-0}" = "1" ]; then
      if [ "$is_elf" = "1" ] && [ -n "$LOADER" ]; then
        exec "$LOADER" "$BIN" "$@"
      fi

      if command -v steam-run >/dev/null 2>&1 && { [ "$can_use_userns" = "1" ] || [ "''${OPENCODE_FORCE_STEAM:-0}" = "1" ]; }; then
        STEAM_RUN_CMD=$(command -v steam-run)
        exec "$STEAM_RUN_CMD" "$BIN" -- "$@"
      else
        exec systemd-run --user --scope -p CPUQuota=60% -p CPUWeight=150 -- "$BIN" "$@"
      fi
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
  goose
  pipxPkg
  aiderCmd
  llmLabCmd
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
{
  # Основной список системных пакетов без `null`.
  packages = builtins.filter (x: x != null) rawList;

  # Явные экспортируемые артефакты нужны другим модулям, которые хотят
  # использовать только опенкод-обёртки, не подтягивая весь системный список.
  inherit opencodeCmd opencodeBin;
}
