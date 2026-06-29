{ config, pkgs, ... }:

{
  # Typography is a session policy: it affects how terminal, X11 and GTK/Qt
  # apps render the same text, so the font stack should be explicit and shared.
  fonts.packages = with pkgs; [
    terminus_font
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    emacs-all-the-icons-fonts
    # Aporetic (nixpkgs `aporetic`): основной шрифт pro-nix, см.
    # configuration.nix. nix-closure гарантирует, что пакет доступен
    # во всех хостах; дублирующее включение здесь идемпотентно.
    aporetic
    # Nerd Fonts: required by `nerd-icons` (consult/ibuffer/dired/completion).
    # FiraCode — primary; Hack и DejaVuSansMono — резерв на случай смены code-font
    # (кандидаты в pro-ui-fonts.el ищутся именно в этом порядке).
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.dejavu-sans-mono
    liberation_ttf
    dejavu_fonts
    cantarell-fonts
  ];

  # defaultFonts уже заданы в configuration.nix (Aporetic Sans/Mono first,
  # DejaVu fallback). Здесь только добавляем serif, которого нет в базовом
  # слое — для pro-* UI, который использует variable-pitch с засечками.
  fonts.fontconfig.defaultFonts = {
    serif = [ "Aporetic Serif" "DejaVu Serif" ];
  };

  environment.etc."fonts.conf".source = ../conf/fonts.conf;
  environment.etc."gtk-3.0/settings.ini".source = ../conf/gtk-3.0-settings.ini;
  environment.etc."gtk-4.0/settings.ini".source = ../conf/gtk-4.0-settings.ini;
  environment.etc."gtk-2.0/gtkrc".source = ../conf/gtkrc-2.0;
  environment.etc."xdg/qt5ct/qt5ct.conf".source = ../conf/qt5ct.conf;
  environment.etc."xdg/qt6ct/qt6ct.conf".source = ../conf/qt6ct.conf;
  environment.etc."xdg/kdeglobals".source = ../conf/kdeglobals;
  environment.etc."X11/Xresources".text = builtins.readFile ../conf/Xresources;
  environment.etc."xdg/dunst/dunstrc".source = ../conf/dunstrc;
}
