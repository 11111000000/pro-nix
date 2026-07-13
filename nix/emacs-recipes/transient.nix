{ stdenv
, emacs
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
# Этот recipe — прямой `mkDerivation` поверх официального тега v0.13.5
# (без elpa2nix, как и llm.nix). Содержимое распаковывается стандартно,
# все .el файлы попадают в `site-lisp/<pname>/` напрямую.
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

stdenv.mkDerivation rec {
  pname = "transient";
  version = "0.13.5";

  src = fetchFromGitHub {
    owner = "magit";
    repo = "transient";
    rev = "v${version}";
    hash = "sha256-r0LJ6EqlPJDKzbW5Nm3QR34Ha7nz6r8gKax7jKOTIyE=";
  };

  nativeBuildInputs = [ emacs ];

  buildInputs = [
    compat
    cond-let
    llama
    seq
  ];

  dontConfigure = true;

  # В v0.13.x исходники лежат в подкаталоге `lisp/`. Устанавливаем все
  # .el оттуда; pkg.el автогенерируется elpa-стилем, но для прямого
  # mkDerivation мы просто кладём всё что есть.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    for f in lisp/transient.el lisp/transient-*.el; do
      [ -f "$f" ] && install -m644 "$f" $out/share/emacs/site-lisp/${pname}/
    done
    runHook postInstall
  '';

  meta = with lib; {
    description = "Transient commands — prefix/suffix UI primitives used by Magit";
    homepage = "https://github.com/magit/transient";
    license = with licenses; [ gpl3Plus ];
    platforms = platforms.unix;
  };
}