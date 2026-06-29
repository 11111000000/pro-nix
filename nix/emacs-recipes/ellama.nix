{ stdenv, emacs, lib, fetchFromGitHub
, emacsPackages
, emacsPackages_llm, emacsPackages_plz, emacsPackages_transient
, emacsPackages_compat, emacsPackages_yaml
, emacsPackages_plz_event_source ? null
, emacsPackages_plz_media_type ? null }:

# Ellama: Emacs client for local (Ollama) and cloud LLMs.
#
# - Source: s-kostyaev/ellama (https://github.com/s-kostyaev/ellama, 948+ stars).
# - Pinned commit: 09857e5d2ec8a7bfc68b510a2a6afce2b165566b (v1.29.0, 2026-06-26).
# - License: GPL-3.0-or-later.
# - Upstream is also on GNU ELPA, but pinning to GitHub lets us pick up the
#   agentic-coding profile, DLP hooks, and skill loader ahead of ELPA release
#   cadence. Re-pin from `git ls-remote https://github.com/s-kostyaev/ellama.git`
#   when bumping.
# - Runtime deps (declared in ellama.el Package-Requires): llm >= 0.31.1,
#   plz, transient >= 0.7, compat >= 29.1, yaml. All ship with nixpkgs
#   emacsPackages, so `buildInputs` provides them on EMACSLOADPATH for the
#   byte-compile step (mirrors the carriage recipe pattern).
#
# Important: `llm` принимается как explicit arg `emacsPackages.llm`, потому
# что `emacs.pkgs.llm` (т.е. `super.emacsPackages.llm`) реферит на
# **broken upstream** emacs-llm-0.27.2 (архив удалён с ELPA mirrors).
# Наш patched llm зарегистрирован в localRecipes (см. override ниже),
# но alphabetic-order evaluation ema < llm означает что когда этот
# recipe вычисляется, `super.emacsPackages.llm` всё ещё broken-upstream.
# Передача `emacsPackages` явно через callPackage из overlay (где
# `localRecipes.llm` уже установлен) решает это.
#
# Why fetchFromGitHub instead of a submodule: we don't ship local patches
# against ellama, so reproducibility is purely the commit pin + SRI hash.
# Submodules would force `git+file://...?submodules=1` everywhere without any
# benefit (AGENTS.md §6c).
stdenv.mkDerivation rec {
  pname = "ellama-patched-llm";
  version = "1.29.0-unstable-2026-06-26";

  src = fetchFromGitHub {
    owner = "s-kostyaev";
    repo = "ellama";
    rev = "09857e5d2ec8a7bfc68b510a2a6afce2b165566b";
    hash = "sha256-45WdUSsaMqwsfEu8GPy5zpXoI3zM7vQS6cefcHKwPAI=";
  };

  nativeBuildInputs = [ emacs ];

  # Все runtime deps берутся ЯВНО из переданных `emacsPackages_*` (явные
  # параметры). Это гарантирует, что alphabetic-order в localRecipes attrset
  # не подсунет upstream broken `emacs-llm-0.27.2` (у которого архив
  # удалён с ELPA mirrors).
  buildInputs = [
    emacsPackages_llm
    emacsPackages_plz
    emacsPackages_transient
    emacsPackages_compat
    emacsPackages_yaml
    # plz транзитивно тянет ещё plz-event-source и plz-media-type.
    # ellama-transient.el/eval/tools/dlp делают (require ...) напрямую.
    # Если Nix не передаст их как deps, byte-compile упадёт с
    # `Cannot open load file: plz-{event-source,media-type}`.
    emacsPackages_plz_event_source
    emacsPackages_plz_media_type
  ];

  dontConfigure = true;

  # Byte-compile every shipped .el file. `transient` and `llm` are not loaded
  # by ellama.el at top level (only conditionally), but providing them on
  # the load path makes the byte-compiler happy when one of the sub-modules
  # pulls them in via `require`.
  #
  # Мы _явно_ добавляем -L для каждого buildInput + recursive walk для
  # subdirs (plz → plz, plz-event-source, plz-media-type; yaml → МНОГО dirs).
  # propagatedBuildInputs через nixpkgs upstream работают прозрачно
  # (`addEmacsNativeLoadPath`), но наши рецепты (llm.nix, ellama.nix)
  # используют простой `mkDerivation` без этого magic.
  buildPhase = ''
    runHook preBuild
    # Recursive -L: каждый buildInput может иметь multiple .el сайты в
    # подкаталогах (plz → plz + plz-event-source + plz-media-type;
    # yaml → yaml.el в подкаталоге). Используем find для рекурсивного поиска.
    # Цикл по 5 отдельным paths, каждый interpolated антистрингом:
    LP_ARGS=""
    for PKG_ROOT in \
      ${emacsPackages_llm}/share/emacs \
      ${emacsPackages_plz}/share/emacs \
      ${emacsPackages_transient}/share/emacs \
      ${emacsPackages_compat}/share/emacs \
      ${emacsPackages_yaml}/share/emacs \
      ${emacsPackages_plz_event_source}/share/emacs \
      ${emacsPackages_plz_media_type}/share/emacs; do
      if [ -d "$PKG_ROOT" ]; then
        for SUBDIR in $(find "$PKG_ROOT" -type d); do
          [ -n "$(ls "$SUBDIR"/*.el 2>/dev/null)" ] && LP_ARGS="$LP_ARGS -L $SUBDIR"
        done
      fi
    done
    emacs --batch -Q -L . $LP_ARGS \
      -f batch-byte-compile \
      ellama.el \
      ellama-blueprint.el \
      ellama-community-prompts.el \
      ellama-context.el \
      ellama-eval.el \
      ellama-manual.el \
      ellama-skills.el \
      ellama-tools-dlp.el \
      ellama-tools.el \
      ellama-transient.el
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    install -m644 *.el  $out/share/emacs/site-lisp/${pname}/
    install -m644 *.elc $out/share/emacs/site-lisp/${pname}/
    # ellama ships a `skills/` directory and a `blueprints/` directory
    # alongside the .el files. They are read at runtime (see
    # `ellama-skills-global-path` and `ellama-blueprints` defcustoms), so
    # copy them as-is.
    if [ -d skills ]; then
      cp -r skills $out/share/emacs/site-lisp/${pname}/skills
    fi
    if [ -d blueprints ]; then
      cp -r blueprints $out/share/emacs/site-lisp/${pname}/blueprints
    fi
    runHook postInstall
  '';

  meta = with lib; {
    description = "Ellama — Emacs client for local (Ollama) and cloud LLMs with tool-use, AGENTS.md awareness, DLP, sessions, and skill loading";
    homepage = "https://github.com/s-kostyaev/ellama";
    license = with licenses; [ gpl3Plus ];
    platforms = platforms.unix;
  };
}
