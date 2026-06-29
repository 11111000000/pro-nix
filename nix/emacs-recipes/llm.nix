{ stdenv, emacs, lib, fetchFromGitHub }:

# llm (ahyatt/llm) — абстракция провайдеров LLM для Emacs. GNU ELPA, но
# nixpkgs-рецепт эмaскальной версии 0.27.2 застрял на tar-архиве
# `llm-0.27.2.tar`, который удалён с ELPA mirrors (HTTP 404 на всех mirrors).
# ellama 1.29+ требует llm 0.31+, поэтому upstream рецепт бесполезен.
#
# Этот recipe — прямой `mkDerivation` поверх `fetchFromGitHub` HEAD
# (без использования elpa2nix). Содержимое распаковывается стандартно,
# все .el файлы и `llm-pkg.el` попадают в `site-lisp/` напрямую.
#
# Pin: 745f9b10b165aeae2175d3da02c5c794eabf603b (2026-06-28).
# License: GPL-3.0.
#
# Зависимости (Package-Requires в llm.el):
#   - emacs      >= 29.1
#   - compat     >= 30.1.0.1
#   - plz        >= 0.8

stdenv.mkDerivation rec {
  pname = "llm";
  version = "unstable-2026-06-28";

  src = fetchFromGitHub {
    owner = "ahyatt";
    repo = "llm";
    rev = "745f9b10b165aeae2175d3da02c5c794eabf603b";
    hash = "sha256-V4UtuLZWP9+PPq98MBlhWcVv98T45/wvARqTVcBObzk=";
  };

  nativeBuildInputs = [ emacs ];

  buildInputs = with emacs.pkgs; [
    compat
    plz
  ];

  dontConfigure = true;

  # Инсталлируем только .el файлы llm-* (исключаем утилиты,
  # тесты, .git, .github, и assets вроде animal.jpeg/test.pdf).
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    # Все основные .el и *-pkg.el попадают в install.
    for f in llm.el llm-*.el; do
      [ -f "$f" ] && install -m644 "$f" $out/share/emacs/site-lisp/${pname}/
    done
    runHook postInstall
  '';

  meta = with lib; {
    description = "llm — Emacs LLM provider abstraction (Ollama/OpenAI/Claude/Gemini/DeepSeek/OpenRouter/...)";
    homepage = "https://github.com/ahyatt/llm";
    license = with licenses; [ gpl3Plus ];
    platforms = platforms.unix;
  };
}
