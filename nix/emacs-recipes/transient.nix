{ stdenv
, emacs
, trivialBuild
, lib
, fetchFromGitHub
, compat
, cond-let
, llama
, seq
}:

# transient (magit/transient) — команды с префиксом/суффиксом, на которых
# построен интерфейс Magit. Nixpkgs-рецепт `emacsPackages.transient`
# (на 2026-07) собирает коммит `053d56e4` от 2025-10-06, в котором
# `transient-version` всё ещё `"0.10.1"` — между релизами v0.11.0/v0.13.5
# Magit обновил требование до `>= 0.13`, и эта версия уже не подходит.
# Результат: при загрузке Magit выбрасывает emergency "Magit requires
# 'transient' >= 0.13".
#
# Этот recipe — прямой `trivialBuild` поверх официального тега v0.13.5
# (без `elpa2nix`/`melpa2nix`). `trivialBuild` запускает
# `emacs -l package -f package-initialize -L . --batch -f batch-byte-compile`
# и автоматически подхватывает transitive deps из `propagatedBuildInputs`
# (здесь — `compat`, `cond-let`, `llama`, `seq`).
#
# NB: не пытаемся повторить upstream-Makefile (он использует
# относительные пути `../../compat`, которые Nix не подкладывает). Вместо
# этого байт-компилируем через Emacs `package-initialize`, который
# читает `<pkg>-pkg.el` из buildInputs и поднимает всё в load-path.
#
# Pin: tag v0.13.5 (commit 3d20a78…, 2026-07-01).
# License: GPL-3.0.
#
# Зависимости (Package-Requires в transient.el):
#   - emacs    >= 28.1
#   - compat   >= 31.0
#   - cond-let >= 1.1
#   - llama    >= 1.0
#   - seq      >= 2.24
#
# NB: `compat` в nixpkgs 25.11 запинен на 30.1.0.1 — перебиваем в overlay
# (см. nix/overlays/emacs-extra.nix) на свежий тег 31.0.0.2
# (emacs-compat/compat@df03e91, 2026-07-09) через собственный fetchFromGitHub.

trivialBuild rec {
  pname = "transient";
  version = "0.13.5";

  src = fetchFromGitHub {
    owner = "magit";
    repo = "transient";
    rev = "v${version}";
    hash = "sha256-r0LJ6EqlPJDKzbW5Nm3QR34Ha7nz6r8gKax7jKOTIyE=";
  };

  # propagatedBuildInputs, а не buildInputs: ellama и другие пакеты,
  # которые требуют `transient`, тянут transitively `cond-let` (через
  # require внутри transient.el). Nix не подкладывает transitive deps
  # из buildInputs — только из propagatedBuildInputs (через
  # `addEmacsNativeLoadPath` в trivialBuild). Иначе байт-компиляция
  # ellama падает с `Cannot open load file: cond-let`.
  propagatedBuildInputs = [
    compat
    cond-let
    llama
    seq
  ];

  # В v0.13.x исходники лежат в подкаталоге `lisp/`, не в корне.
  # `trivialBuild` байт-компилирует и ставит `*.el` из cwd. Переходим
  # в `lisp/` и копируем файлы оттуда.
  buildPhase = ''
    runHook preBuild

    if [[ ! ( -z "''${makeFlags-}" && -z "''${makefile:-}" && ! ( -e Makefile || -e makefile || -e GNUmakefile ) ) ]]; then
      foundMakefile=1
    fi

    cd lisp
    emacs -l package -f package-initialize \
      --eval "(setq byte-compile-debug t)" \
      --eval "(setq byte-compile-error-on-warn nil)" \
      -L . --batch -f batch-byte-compile *.el

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    LISPDIR=$out/share/emacs/site-lisp
    install -d $LISPDIR
    install *.el *.elc $LISPDIR

    runHook postInstall
  '';

  meta = with lib; {
    description = "Transient commands — prefix/suffix UI primitives used by Magit";
    homepage = "https://github.com/magit/transient";
    license = with licenses; [ gpl3Plus ];
    platforms = platforms.unix;
  };
}