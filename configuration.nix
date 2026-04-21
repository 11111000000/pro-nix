# configuration.nix — системная конфигурация NixOS для этого репозитория.
#
# Назначение:
# Этот файл задаёт базовый набор системных политик и импортирует модули,
# формирующие поведение хостов в коллекции pro-nix. Здесь описаны только
# глобальные, кросс-хостовые политики; локальные хостовые переопределения
# размещаются в `hosts/*` или в `./local.nix`.
#
# Что должно быть здесь и почему:
# - импорты модулей (./modules) — общая политика и базовый профиль;
# - базовые параметры загрузчика и ядра — чтобы поведение системы было предсказуемым;
# - общая политика безопасности (sudo, apparmor) и сетевые настройки.
#
# Практика: избегайте размещения в этом файле временных отладочных правок;
# если требуется эксперимент — положите изменения в `local.nix`.

{ config, pkgs, lib, emacsPkg ? pkgs.emacs, ... }:

  let
  local = if builtins.pathExists ./local.nix then import ./local.nix else { };
  hostName = local.hostName or "nixos";
  emacsPkg = pkgs.emacs30 or pkgs.emacs;
  in

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 1: Импортируемые модули и включение дополнительной логики
#
# Сначала собирается контур слоёв: железо, пользовательская база и локальные исключения. Здесь решается, какие различия допускаются, а какие должны жить отдельно.

  {
  environment.etc."pro/emacs-keys.org".source = ./emacs-keys.org;

   imports = [
     # Аппаратные параметры задаются на уровне профиля хоста: hardware-configuration.nix больше не используется
     # ./hardware-configuration.nix


    # Общие смысловые модули формируют shared policy и не должны знать о личных привычках больше, чем требуется.
    ./modules/pro-users.nix
    ./modules/pro-services.nix
    ./modules/pro-storage.nix
    ./modules/pro-privacy.nix
    ./modules/pro-peer.nix
    ./modules/headscale.nix
    ./modules/pro-desktop.nix
    ./modules/nix-cuda-compat.nix

    # Локальные переопределения конкретного хоста оставлены там, где они действительно принадлежат машине, а не профилю.
  ] ++ lib.optionals (builtins.pathExists ./local.nix) [ ./local.nix ] ++ [

    # Home Manager подключается как слой пользовательской формы, чтобы личная среда не растворялась в системных файлах.
    # Вспомогательный модуль для переназначения клавиш подключён только как потенциальный рабочий инструмент, а не как обязательная часть ядра.
    # <nixos-unstable/nixos/modules/services/misc/xremap.nix>
  ];


# ──────────────────────────────────────────────────────────────────────────────
# Раздел 2: Загрузчик системы и параметры ядра
#
# Здесь задаётся способ входа в систему: EFI, число поколений, поведение ядра и границы того, что можно считать надёжным стартом.

  boot.loader.grub.enable = true;                     # GRUB остаётся безопасной общей точкой входа для разных машин.
  boot.loader.grub.device = lib.mkDefault "nodev";   # Для EFI-сценария загрузчик живёт без привязки к конкретному диску.
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;        # EFI-переменные можно менять из этой установки.
  boot.loader.efi.efiSysMountPoint = lib.mkDefault "/boot";         # Точка ESP фиксируется явно, чтобы путь к загрузчику не расплывался.
  boot.loader.timeout = 5;                            # Короткая пауза оставляет выбор, но не превращает старт в ожидание.
  boot.loader.grub.useOSProber = false;               # Явная загрузка без автоматического поиска чужих систем.

  boot.plymouth.enable = true;                        # Plymouth смягчает переход от firmware к рабочему миру.
  boot.plymouth.theme = "spinner";                     # Спиннер выбран как спокойная форма ожидания без декоративного шума.

  boot.kernelPackages = pkgs.linuxPackages_6_6;        # LTS-ядро здесь поддерживает устойчивость сна и пробуждения на этом поколении железа.
  boot.kernel.sysctl."kernel.sysrq" = 1;               # SysRq оставлен как аварийный выход, когда система перестаёт отвечать как среда, а не как инструмент.

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 3: Сетевая конфигурация и имя машины
#
# Здесь определяется имя машины и тот сетевой менеджер, который будет держать связь с внешним миром без ручной пляски вокруг Wi-Fi.

  networking.hostName = lib.mkDefault hostName;  # Базовое имя задаётся только как запасной вариант, а машина может переопределить его на своём уровне.

  # Enable pro-peer discovery and key sync by default so hosts in the same
  # LAN advertise via mDNS and can receive centrally-managed authorized_keys.
  pro-peer.enable = true;
  pro-peer.enableKeySync = true;

  # Старую беспроводную схему не используем: сеть должна управляться одной понятной системой, а не несколькими конкурирующими.
  # networking.wireless.enable = true;

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 4: Часовой пояс и языковая локализация
#
# Локализация здесь задаёт не просто язык, а бытовую меру времени, адресов и типографики рабочего поля.

  time.timeZone = "Asia/Irkutsk";           # Часовой пояс выбран как точка совпадения с реальным ритмом работы.

  # Основная локаль системы задаёт русский Unicode как естественный язык рабочего поля.
  i18n.defaultLocale = "ru_RU.UTF-8";

  # Дополнительные LC-параметры удерживают приложения в одном культурном и числовом режиме.
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };
  # Enable and configure sudo via NixOS module so the binary is installed
  # and the setuid bit is managed correctly by the activation scripts.
  # Note: this is also set in modules/pro-users.nix for host-wide defaults.
  security.sudo.enable = true;
  # Prefer wheel users to require a password by default, but allow host modules
  # (eg. modules/pro-users.nix) to override this. Use lib.mkDefault so later
  # module definitions can set a different value without an option conflict.
  security.sudo.wheelNeedsPassword = lib.mkDefault true;

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 5: Аппаратная поддержка и базовые сервисы
#
# Здесь обеспечивается поддержка ввода (мыши, тачпады), Bluetooth, энергосбережения, 
# а также автоматическое обновление микрокода процессоров Intel. Настроены параметры 
# управления электропитанием, очистки временных файлов, и актуализация прошивок для оборудования.

  services.libinput = {
    enable = true;                      # Универсальный драйвер для всех устройств ввода.
    touchpad.disableWhileTyping = true;  # Блокировать случайные нажатия тачпада во время печати.
  };

  hardware.bluetooth.enable = true;         # Включаем поддержку Bluetooth.
  hardware.bluetooth.settings = {
    General = { AutoEnable = true; };       # Адаптер включается автоматически.
  };
  services.blueman.enable = true;           # Графический интерфейс управления Bluetooth.

  powerManagement.enable = true;           # Общесистемное управление питанием.
  powerManagement.resumeCommands = ''
    modprobe -r battery ac 2>/dev/null || modprobe -r battery
    sleep 1
    modprobe battery
    modprobe ac 2>/dev/null || true
    udevadm trigger -s power_supply || true
    udevadm settle -t 5 || true
    ${pkgs.upower}/bin/upower --enumerate >/dev/null 2>&1 || true
    systemctl try-restart upower.service 2>/dev/null || true
  '';
  
  # Параметры сна/гибернации.
  # Configure systemd-logind via structured settings (replacement for extraConfig)
  services.logind.settings = {
    Login = {
      LidSwitchIgnoreInhibited = "no";
      HandlePowerKey = "suspend-then-hibernate";
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "suspend";
    };
  };

  services.upower = {
    enable = true;
    usePercentageForPolicy = true;
    percentageLow = 15;
    percentageCritical = 10;
    percentageAction = 8;
    criticalPowerAction = "Hibernate";
  };
  services.power-profiles-daemon.enable = true;    # Современный демон профилей питания.

  services.xserver.videoDrivers = [ "modesetting" ];   # Драйвер видео: для большинства Intel Xe рекомендуется modesetting.

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 6: Особенности Nix и расширенные возможности
#
# Включены дополнительные механизмы для поддержки AppImage, динамических бинарников, 
# а также активация экспериментальных функций системы сборки Nix (flakes). 

  # nix-ld injects a compatibility library path which can cause GTK/GLib
  # library version mismatches for GUI applications (see docs/research/analysis-results.txt).
  # Disable by default to avoid `GdkDisplayManager` / GLib type registration errors
  # (telegram-desktop and other GTK apps may crash if nix-ld provides incompatible libs).
  programs.nix-ld.enable = false;

  # Включение flakes, регулярная очистка и оптимизация кэша пакетов.
  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    settings.connect-timeout = 5;
    settings.fallback = true;
    # Use cgroups so Nix places build processes into cgroups and systemd
    # resource controls (CPUQuota/MemoryMax) can be applied per-build.
    settings.use-cgroups = true;
    # Limit parallel builds to a conservative number to avoid saturating CPU.
    # Set to 2 for interactive responsiveness on typical desktop machines.
    settings.max-jobs = 2;
    # Сначала используем публичный кэш и его Fastly-зеркало, чтобы сборка быстрее уходила в готовые бинарники.
    settings.substituters = lib.mkForce [
      "https://cache.nixos.org"
      "https://nix-mirror.freetls.fastly.net"
    ];
    settings.trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    optimise.automatic = true;
  };

  # Позволяем использовать не полностью открытые пакеты.
  nixpkgs.config = {
    allowUnfree = true;
  };

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 7.1: Steam и игровые приложения
#
# Здесь включается поддержка Steam и игровых приложений для запуска коммерческих игр.

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Открываем порты для Remote Play
    dedicatedServer.openFirewall = true; # Открываем порты для выделенных серверов
  };

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 7: Дополнительные службы и системная среда
  services.udisks2.enable = true;
  services.guix.enable = true;
  services.flatpak.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-gtk ];
  };

  # By default optional heavy packages are disabled. To enable them set
  # `enableOptional = true` when importing `system-packages.nix`.
  environment.systemPackages = with pkgs; [ just jq ] ++ (import ./system-packages.nix { inherit pkgs emacsPkg; enableOptional = false; });

  fonts.packages = with pkgs; [
    terminus_font
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    (stdenv.mkDerivation rec {
      name = "aporetic-fonts";
      src = ./fonts;
      installPhase = ''
        mkdir -p $out/share/fonts/truetype
        cp $src/*.ttf $out/share/fonts/truetype/
      '';
    })
    liberation_ttf
    dejavu_fonts
    cantarell-fonts
  ];

  # Prefer Aporetic Sans as the system sans font and Aporetic Sans Mono for monospace.
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Aporetic Sans" "DejaVu Sans" ];
    monospace = [ "Aporetic Sans Mono" "Terminus" ];
  };

  # Optional guidance: hosts that need to force VT native resolution can add
  # a kernel parameter like "video=1920x1080" in their host configuration.

  # Deploy fontconfig and desktop/GTK/Qt configuration files so desktop
  # environments and toolkits pick up the Aporetic fonts as defaults.
  environment.etc."fonts.conf".source = ./conf/fonts.conf;
  environment.etc."gtk-3.0/settings.ini".source = ./conf/gtk-3.0-settings.ini;
  environment.etc."gtk-4.0/settings.ini".source = ./conf/gtk-4.0-settings.ini;
  environment.etc."gtk-2.0/gtkrc".source = ./conf/gtkrc-2.0;
  environment.etc."xdg/qt5ct/qt5ct.conf".source = ./conf/qt5ct.conf;
  environment.etc."xdg/qt6ct/qt6ct.conf".source = ./conf/qt6ct.conf;
  environment.etc."xdg/kdeglobals".source = ./conf/kdeglobals;
  environment.etc."X11/Xresources".source = ./conf/Xresources;
  environment.etc."xdg/dunst/dunstrc".source = ./conf/dunstrc;

  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableSystemSlice = true;
    enableUserSlices = true;
  };
  # Prevent individual services (notably the nix daemon) from taking all CPU.
  # Limit the nix-daemon service and enable default CPU accounting so user processes
  # inherit reasonable defaults. Tweak values to taste (CPUQuota is a percentage).
  systemd.services."nix-daemon".serviceConfig = {
    # Do not let the daemon saturate the machine — allow up to 75% of total CPU.
    CPUQuota = "75%";
    # Lower CPUWeight so other services keep some proportionate share.
    CPUWeight = "200";
  };

  # Make systemd enable CPU accounting and set a default weight for slices.
  # This helps ensure user processes (user.slice) are subject to accounting and
  # will respect per-unit limits when applied.
  # Use structured systemd settings (replacement for deprecated extraConfig).
  systemd.settings = {
    Manager = {
      DefaultCPUAccounting = "yes";
      DefaultCPUWeight = "100";
      DefaultTasksMax = "8192";
      DefaultCPUQuotaPerSecUSec = "100000";
    };
  };
  
  environment.variables = {
    LANG = "ru_RU.UTF-8";
    LC_CTYPE = "ru_RU.UTF-8";
    GTK_KEY_THEME = "Emacs";
    # Avoid forcing Qt to load GTK platformtheme plugin (libqgtk3), which can
    # cause GTK/GLib symbol conflicts and crashes in mixed GTK/Qt applications
    # (see analysis-results.txt). Leave empty to use default Qt theming.
    QT_QPA_PLATFORMTHEME = "";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };

  system.stateVersion = "25.11";
}
