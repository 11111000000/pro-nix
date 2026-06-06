# Название: modules/pro-haskell.nix — Haskell toolchain для хоста разработки
#
# Цель:
#   Вынести GHC/Haskell tooling в отдельный узкий модуль, чтобы включать его
#   только на хостах, где Haskell действительно используется как рабочая среда.
#
# Контракт:
#   - Модуль добавляет только Haskell toolchain (GHC, HLS, build tools, linters,
#     formatters) через environment.systemPackages.
#   - Модуль не включает desktop, X11, display manager или другие рабочие
#     слои.
#   - Подключается host-specific, без влияния на cf19/vm.
#
# Proof:
#   `nix eval .#nixosConfigurations.huawei.config.environment.systemPackages --json`
#   и проверка наличия ghc/haskell-language-server/hlint/fourmolu.
{ pkgs, lib, ... }:

{
  # Package list uses plain assignment (not lib.mkDefault) so it is always
  # concatenated with lists from other imported modules.
  environment.systemPackages = with pkgs; [
    # Compilers and language server.
    ghc
    haskell-language-server
    # Build tools.
    cabal-install
    stack
    # REPL/load helper used by the emacs module.
    haskellPackages.ghcid
    # Linter (called by emacs-side `pro-haskell-lint').
    hlint
    # Formatter (called by emacs-side `pro-haskell-format-buffer').
    fourmolu
    # Per-user toolchain manager so ad-hoc projects can pull newer GHCs.
    # ghcup is not present in all nixpkgs channels; leave it out of the
    # default host package set to avoid eval failures. Operators who need
    # ghcup can add it to extraPackages on their host module.
  ];
}
