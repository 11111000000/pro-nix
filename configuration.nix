# configuration.nix: Ядро системы NixOS
# 
# Этот файл задаёт каркас системы NixOS как рабочего мира, где каждая секция объясняет не только параметр, но и роль слоя в общей архитектуре.
#
# Структура собрана как последовательность слоёв: импорты, ядро, аппаратная опора, локализация, графика, сервисы, пользовательская оболочка и пакетный контур.
# Такой порядок нужен не ради красоты, а чтобы система оставалась читаемой при долгой жизни и частых переносах.
#
# Пример ориентирован на ноутбук с Intel, NVMe и Bluetooth; при другом железе меняется только то, что действительно зависит от машины.

{ config, pkgs, lib, ... }:

  let
  local = if builtins.pathExists ./local.nix then import ./local.nix else { };
  hostName = local.hostName or "nixos";
  emacsPkg = pkgs.emacs30 or pkgs.emacs;
  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/refs/heads/release-25.11.tar.gz";
    sha256 = "16mcnqpcgl3s2frq9if6vb8rpnfkmfxkz5kkkjwlf769wsqqg3i9";
  };
  in

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 1: Импортируемые модули и включение дополнительной логики
#
# Сначала собирается контур слоёв: железо, пользовательская база и локальные исключения. Здесь решается, какие различия допускаются, а какие должны жить отдельно.

  {
  environment.etc."pro/emacs-keys.org".source = ./emacs-keys.org;

  imports = [
    # Сгенерированный контур железа фиксирует то, что определено физической машиной, а не волей автора.
    ./hardware-configuration.nix

    # Общие смысловые модули формируют shared policy и не должны знать о личных привычках больше, чем требуется.
    ./modules/pro-users.nix
    ./modules/pro-services.nix
    ./modules/pro-storage.nix
    ./modules/pro-privacy.nix
    ./modules/pro-desktop.nix
    ./modules/nix-cuda-compat.nix

    # Локальные переопределения конкретного хоста оставлены там, где они действительно принадлежат машине, а не профилю.
  ] ++ lib.optionals (builtins.pathExists ./local.nix) [ ./local.nix ] ++ [

    # Home Manager подключается как слой пользовательской формы, чтобы личная среда не растворялась в системных файлах.
    (import "${home-manager}/nixos")

    # Вспомогательный модуль для переназначения клавиш подключён только как потенциальный рабочий инструмент, а не как обязательная часть ядра.
    # <nixos-unstable/nixos/modules/services/misc/xremap.nix>
  ];


# ──────────────────────────────────────────────────────────────────────────────
# Раздел 2: Загрузчик системы и параметры ядра
#
# Здесь задаётся способ входа в систему: EFI, число поколений, поведение ядра и границы того, что можно считать надёжным стартом.

  boot.loader.systemd-boot.enable = true;             # systemd-boot выбран как простой и предсказуемый вход в систему.
  boot.loader.efi.canTouchEfiVariables = true;        # EFI-переменные можно менять из этой установки.
  boot.loader.efi.efiSysMountPoint = "/boot";         # Точка ESP фиксируется явно, чтобы путь к загрузчику не расплывался.
  boot.loader.systemd-boot.configurationLimit = 6;    # Небольшой лимит поколений удерживает ESP в рабочем размере.
  boot.loader.timeout = 5;                            # Короткая пауза оставляет выбор, но не превращает старт в ожидание.
  boot.loader.systemd-boot.editor = true;             # Редактор загрузки оставлен для редких вмешательств без вскрытия всего контура.

  boot.plymouth.enable = true;                        # Plymouth смягчает переход от firmware к рабочему миру.
  boot.plymouth.theme = "spinner";                     # Спиннер выбран как спокойная форма ожидания без декоративного шума.

  boot.kernelPackages = pkgs.linuxPackages_6_6;        # LTS-ядро здесь поддерживает устойчивость сна и пробуждения на этом поколении железа.
  boot.kernelParams = [ "mem_sleep_default=s2idle" "i915.enable_psr=0" "nvme_core.default_ps_max_latency_us=0" "acpi_backlight=native" ];
  boot.kernel.sysctl."kernel.sysrq" = 1;               # SysRq оставлен как аварийный выход, когда система перестаёт отвечать как среда, а не как инструмент.
  boot.resumeDevice = "/dev/nvme0n1p3";                 # Устройство resume фиксирует путь к гибернации на этой машине.

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 3: Сетевая конфигурация и имя машины
#
# Здесь определяется имя машины и тот сетевой менеджер, который будет держать связь с внешним миром без ручной пляски вокруг Wi-Fi.

  networking.hostName = hostName;  # Имя хоста берётся из локального конфигурационного слоя и не смешивается с общим репозиторием.

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
  security.sudo.wheelNeedsPassword = false;

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

    for n in XHCI RP05; do
      if awk -v d="$n" '$1==d && $3 ~ /\*enabled/' /proc/acpi/wakeup >/dev/null 2>&1; then
        echo "$n" > /proc/acpi/wakeup || true
      fi
    done
  '';
  
  # Параметры сна/гибернации.
  services.logind = {
    settings.Login = {
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

  hardware.enableAllFirmware = true;        # Всегда иметь под рукой последние прошивки для Wi-Fi, Bluetooth и проч.

  # Добавляем прошивку Intel SOF для Tiger Lake (исправляет "SOF firmware ... not found" и отсутствие /dev/snd/pcm*):
  hardware.firmware = [ pkgs.sof-firmware ];

  hardware.cpu.intel.updateMicrocode = true; # Микрокод Intel — критично для безопасности.
  hardware.uinput.enable = true;            # Для evremап: предоставляет /dev/uinput и группу uinput.
  boot.extraModprobeConfig = ''
    options snd-intel-dspcfg dsp_driver=1
  '';

  services.xserver.videoDrivers = [ "modesetting" ];   # Драйвер видео: для большинства Intel Xe рекомендуется modesetting.
  # Используем swap-файл на диске для поддержки гибридного сна и гибернации.
  swapDevices = [
    { device = "/dev/nvme0n1p3"; }
  ];

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 6: Особенности Nix и расширенные возможности
#
# Включены дополнительные механизмы для поддержки AppImage, динамических бинарников, 
# а также активация экспериментальных функций системы сборки Nix (flakes). 

  programs.nix-ld.enable = true;  

  # Включение flakes, регулярная очистка и оптимизация кэша пакетов.
  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    settings.connect-timeout = 5;
    settings.fallback = true;
    # Сначала используем более быстрый community-кеш, а к публичному возвращаемся только при необходимости.
    settings.substituters = lib.mkForce [
      "https://nix-community.cachix.org?priority=1"
      "https://cache.nixos.org?priority=50"
    ];
    settings.trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    settings.trusted-substituters = [
      "https://nix-community.cachix.org"
      "https://nix-mirror.freetls.fastly.net"
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
# Раздел 7: Дополнительные службы и системная среда
  services.udisks2.enable = true;
  services.guix.enable = true;
  services.flatpak.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-gtk ];
  };

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

  fonts.fontconfig.defaultFonts.monospace = [ "Terminus" "Aporetic Sans Mono" ];

  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableSystemSlice = true;
    enableUserSlices = true;
    settings.OOM = {
      DefaultMemoryPressureDurationSec = "10s";
    };
  };
  
  environment.variables = {
    LANG = "ru_RU.UTF-8";
    LC_CTYPE = "ru_RU.UTF-8";
    GTK_KEY_THEME = "Emacs";
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };

  system.stateVersion = "25.05";

  powerManagement.powerUpCommands = ''
    for n in XHCI RP05; do
      if awk -v d="$n" '$1==d && $3 ~ /\*enabled/' /proc/acpi/wakeup >/dev/null 2>&1; then
        echo "$n" > /proc/acpi/wakeup || true
      fi
    done
  '';
}
