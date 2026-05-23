# Название: modules/pro-haskell.nix — Haskell toolchain для хоста разработки
#
# Цель:
#   Вынести GHC/Haskell tooling в отдельный узкий модуль, чтобы включать его
#   только на хостах, где Haskell действительно используется как рабочая среда.
#
# Контракт:
#   - Модуль добавляет только Haskell toolchain и HLS через
#     environment.systemPackages.
#   - Модуль не включает desktop, X11, display manager или другие рабочие
#     слои.
#   - Подключается host-specific, без влияния на cf19/vm.
#
# Proof:
#   `nix eval .#nixosConfigurations.huawei.config.environment.systemPackages --json`
#   и проверка наличия ghc/haskell-language-server.
{ pkgs, lib, ... }:

{
  environment.systemPackages = lib.mkDefault (with pkgs; [
    ghc
    haskell-language-server
    cabal-install
    haskellPackages.ghcid
  ]);
}
