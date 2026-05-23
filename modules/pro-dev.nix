# Название: modules/pro-dev.nix — Инструменты разработки и сборки
# Кратко: системный слой с редакторскими, компиляционными и LSP-инструментами.
#
# Цель:
#   Предоставить единый и переиспользуемый набор инструментов разработки для
#   всех хостов профиля без смешивания их с минимальным runtime или desktop-слоем.
#
# Контракт:
#   Опции: environment.systemPackages.
#   Побочные эффекты: добавляет компиляторы, build toolchain, LSP-серверы,
#   форматтеры, поисковые утилиты и вспомогательные CLI для разработки.
#
# Как проверить (Proof):
#   `nix eval --json .#nixosConfigurations.<host>.config.environment.systemPackages`
#   и проверка наличия ключевых derivation (`gcc`, `cmake`, `nodejs`, `rust-analyzer`).
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    direnv
    shellcheck
    shfmt
    bat
    tldr
    pipx
    nodejs_20
    esbuild
    nodePackages.prettier
    nodePackages.typescript-language-server
    nodePackages.typescript
    rust-analyzer
    nodePackages."bash-language-server"
    cmake
    gcc
    binutils
    gnumake
    pkg-config
    libtool
    automake
    autoconf
    silver-searcher
    platinum-searcher
    fzf
    lnav
    mosh
    pandoc
    graphviz
    plantuml
    nodePackages.mermaid-cli
    emacsPackages.eldev
    emacsPackages.cask
  ];
}
