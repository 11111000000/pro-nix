{ stdenv
, emacs
, trivialBuild
, lib
, fetchFromGitHub
}:

# compat (emacs-compat/compat) — backwards-compatibility polyfill для Emacs Lisp.
# Nixpkgs-рецепт `emacsPackages.compat` (на 2026-07) запинен на tag
# `30.1.0.1` (Jun 2025), а `transient-0.13.5` требует `compat >= 31.0`.
# Без этого патча `transient.el` не байт-компилируется:
#   transient.el:52:11: Error: Cannot open load file: No such file or
#   directory, cond-let
# (cond-let — это транзитивная зависимость, которая требует свежий compat).
#
# Этот recipe — прямой `trivialBuild` поверх официального тега 31.0.0.2,
# без elpa2nix. `trivialBuild` сам генерирует `<pname>-pkg.el` и
# `<pname>-autoloads.el`, что критично для propagation: consumers
# (transient, magit) делают `(require 'compat)`, и `package.el` находит
# этот compat по autoload (а не ищет вручную через load-path walk).
#
# Pin: tag 31.0.0.2 (commit df03e91…, 2026-07-09).
# License: GPL-3.0.

trivialBuild rec {
  pname = "compat";
  version = "31.0.0.2";

  src = fetchFromGitHub {
    owner = "emacs-compat";
    repo = "compat";
    rev = "${version}";  # теги emacs-compat/compat без префикса 'v'
    hash = "sha256-ptmRg0+ZODG+CeOjaF5jzMmHVrDKujyFiqYW3vWKjS0=";
  };

  meta = with lib; {
    description = "compat — backwards-compatibility polyfill for Emacs Lisp";
    homepage = "https://github.com/emacs-compat/compat";
    license = with licenses; [ gpl3Plus ];
    platforms = platforms.unix;
  };
}