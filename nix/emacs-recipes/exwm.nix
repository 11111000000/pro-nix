{ lib
, trivialBuild
, fetchFromGitHub
, xelb
, compat
}:

# exwm — Emacs X Window Manager (EXWM). Upstream recipe в nixpkgs 25.11
# тянет `exwm-0.34.0.20250919.75516.tar` с elpa.gnu.org, чей tar-archive
# удалён с зеркал retention-политикой GNU ELPA (`cannot download
# exwm-0.34.0.20250919.75516.tar from any mirror`). Прошлый override
# брал `.tar.lz` (вместо `.tar`), но файл с префиксом версии
# `0.35.0.20260704.2` тоже удалился с тех же зеркал спустя несколько
# недель (`HTTP 404`).
#
# Решение — прямой `fetchFromGitHub` поверх `main` HEAD: upstream
# продолжает развивать EXWM, свежие коммиты доступны без retention.
# `trivialBuild` байт-компилирует `*.el` из cwd через
# `emacs --batch -f batch-byte-compile`; transitive deps приходят из
# `propagatedBuildInputs`. Файлы лежат прямо в корне репозитория
# (не под `lisp/`), поэтому отдельный `cd lisp` не нужен — отличие
# от `transient.nix`.
#
# Pin: commit 5cd76bb639df30a8a7d0f0bbf2edeacd75be0548
#       ("Fix exit prompt, remove superfluous question mark",
#        main, 2026-07-18).
# License: GPL-3.0+.
#
# Зависимости (Package-Requires в exwm.el):
#   - emacs >= 27.1
#   - xelb  >= 0.21
#   - compat (transitive через xelb; explicit ускорит первый билд)

trivialBuild rec {
  pname = "exwm";
  version = "0.35.0.20260718.HEAD";

  src = fetchFromGitHub {
    owner = "emacs-exwm";
    repo = "exwm";
    rev = "5cd76bb639df30a8a7d0f0bbf2edeacd75be0548";
    hash = "sha256-4bFk0EMSqaGi+t+ZWm1VuYGs49tuXLnTVVl72LtEgPo=";
  };

  propagatedBuildInputs = [
    xelb
    compat
  ];

  meta = {
    description = "Emacs X Window Manager";
    longDescription = ''
      EXWM (Emacs X Window Manager) is a full-featured tiling X window
      manager for Emacs built on top of XELB.
    '';
    homepage = "https://github.com/emacs-exwm/exwm";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
}
